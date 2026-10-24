import Combine
import CoreLocation
import Foundation
import MapKit
import WidgetKit

enum NinebotInputError: LocalizedError {
    case missingServer
    case missingAccount
    case missingPassword

    var errorDescription: String? {
        switch self {
        case .missingServer:
            return "请先填写 NinePlus 服务器地址"
        case .missingAccount:
            return "请填写手机号"
        case .missingPassword:
            return "请填写密码"
        }
    }
}

enum NinebotVehicleAction: String, CaseIterable, Identifiable {
    case bell
    case openBucket
    case engineStart
    case engineStop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bell: return "寻车铃"
        case .openBucket: return "开座桶"
        case .engineStart: return "上电"
        case .engineStop: return "熄火"
        }
    }

    var resultTitle: String {
        switch self {
        case .bell: return "寻车铃已发送"
        case .openBucket: return "开座桶指令已发送"
        case .engineStart: return "上电指令已发送"
        case .engineStop: return "熄火指令已发送"
        }
    }

    var loadingTitle: String {
        switch self {
        case .bell: return "正在寻车鸣笛"
        case .openBucket: return "正在打开座桶"
        case .engineStart: return "正在开锁"
        case .engineStop: return "正在关锁"
        }
    }

    var subtitle: String {
        switch self {
        case .bell: return "让车辆发出提示音"
        case .openBucket: return "打开座桶"
        case .engineStart: return "车辆进入可骑行状态"
        case .engineStop: return "关闭电源并锁车"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .bell: return "发送寻车铃？"
        case .openBucket: return "打开座桶？"
        case .engineStart: return "车辆上电？"
        case .engineStop: return "车辆熄火？"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .bell:
            return "车辆会发出提示音。"
        case .openBucket:
            return "座桶会被打开，请确认车辆在你身边。"
        case .engineStart:
            return "车辆会进入上电/解锁状态，请确认车辆在你身边。"
        case .engineStop:
            return "车辆会进入熄火/锁车状态，请确认不会影响当前骑行。"
        }
    }

    var systemImage: String {
        switch self {
        case .bell: return "bell.fill"
        case .openBucket: return "shippingbox.fill"
        case .engineStart: return "power.circle.fill"
        case .engineStop: return "lock.fill"
        }
    }

    var isDangerous: Bool {
        switch self {
        case .engineStart, .engineStop, .openBucket:
            return true
        case .bell:
            return false
        }
    }
}

struct NinebotDiagnosticsSnapshot {
    var hasConfiguration: Bool
    var serverText: String
    var accountText: String
    var vehicleCount: Int
    var selectedVehicleName: String
    var dashboardUpdatedAt: Date?
    var lastAppRefreshEvent: NinebotRefreshEvent?
    var lastWidgetRefreshEvent: NinebotRefreshEvent?
    var lastError: String?
    var interfaceRideCount: Int
    var historyPointCount: Int
    var recordedRideCount: Int
    var rideDetailCount: Int
    var resolvedAddressCount: Int
    var dashboardCacheBytes: Int
}

@MainActor
final class NinebotViewModel: ObservableObject {
    @Published var baseURLString = ""
    @Published var bearerToken = ""
    @Published var account = ""
    @Published var password = ""
    @Published var pushDeviceToken: String?
    @Published var loginResult: NinebotLoginResult?
    @Published var dashboard: NinebotDashboard
    @Published var isLoading = false
    @Published var loadingMessage: String?
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var capturePrivacyProtectionEnabled = false
    @Published private(set) var activeVehicleAction: NinebotVehicleAction?
    @Published private(set) var activeVehicleActionSN: String?
    @Published private(set) var history: [String: [NinebotVehicleHistoryPoint]] = [:]
    @Published private(set) var resolvedAddresses: [String: NinebotResolvedAddress] = [:]
    @Published private(set) var recordedRides: [NinebotRecordedRide] = []
    @Published private(set) var rideDetails: [String: NinebotRideDetail] = [:]
    @Published private(set) var loadingRideDetailKeys: Set<String> = []
    @Published private(set) var syncingTravelMonth: String?
    @Published private(set) var vehicleInsights: [String: NinebotVehicleInsights] = [:]

    private let store = NinebotSharedStore()
    private var lastAutomaticRefreshAt: Date?
    private var travelSyncDates: [String: Date] = [:]

    init() {
        let configuration = store.loadConfiguration()
        let loginResult = store.loadLoginResult()
        self.baseURLString = configuration?.baseURLString ?? ""
        self.bearerToken = configuration?.bearerToken ?? ""
        self.loginResult = loginResult
        self.account = loginResult?.phone ?? ""
        self.pushDeviceToken = store.loadPushDeviceToken()
        self.dashboard = store.loadDashboard() ?? .empty
        self.errorMessage = store.loadLastError()
        self.history = Self.historyMap(for: self.dashboard, store: store)
        self.resolvedAddresses = store.loadResolvedAddresses().filter { $0.value.source == Self.addressGeocodingSource }
        self.recordedRides = store.loadRecordedRides()
        self.capturePrivacyProtectionEnabled = store.loadCapturePrivacyProtectionEnabled()
    }

    var hasConfiguration: Bool {
        currentConfiguration.isUsable
    }

    var hasVehicles: Bool {
        !dashboard.vehicles.isEmpty
    }

    var currentAccountDisplay: String {
        let savedPhone = loginResult?.phone?.trimmed ?? ""
        return savedPhone.isEmpty ? "未绑定账号" : savedPhone
    }

    var hasLoginAccount: Bool {
        !(loginResult?.phone?.trimmed ?? "").isEmpty
            && !(loginResult?.sessionToken?.trimmed ?? "").isEmpty
    }

    var isAddressGeocodingEnabled: Bool {
        true
    }

    func refreshOnLaunchIfPossible() async {
        await syncPushDeviceTokenIfPossible()
        await refreshResolvedAddressesIfNeeded(for: dashboard)
        await refreshAutomaticallyIfPossible()
    }

    func refreshWhenActiveIfPossible() async {
        await syncPushDeviceTokenIfPossible()
        await refreshResolvedAddressesIfNeeded(for: dashboard)
        await refreshAutomaticallyIfPossible()
    }

    private func refreshAutomaticallyIfPossible() async {
        guard hasConfiguration else { return }
        guard !isLoading else { return }

        let now = Date()
        if let lastAutomaticRefreshAt, now.timeIntervalSince(lastAutomaticRefreshAt) < 8 {
            return
        }

        lastAutomaticRefreshAt = now
        await refreshDashboard()
    }

    func saveConfiguration() {
        let configuration = currentConfiguration
        guard configuration.isUsable else {
            errorMessage = NinebotInputError.missingServer.localizedDescription
            return
        }

        store.saveConfiguration(configuration)
        errorMessage = nil
        statusMessage = "服务器配置已保存"
    }

    func testConnection() async {
        await runLoadingOperation(message: "正在测试连接") {
            let client = try makeClient()
            try await client.healthCheck()
            self.errorMessage = nil
            self.statusMessage = "服务器连接正常"
        }
    }

    func refreshDashboard() async {
        await runLoadingOperation(message: "正在刷新车况") {
            let client = try makeClient()
            let dashboard: NinebotDashboard
            do {
                dashboard = try await client.fetchCachedDashboard(selectedSN: self.dashboard.selectedSN)
            } catch {
                dashboard = try await client.fetchDashboard(selectedSN: self.dashboard.selectedSN)
            }
            let archivedDashboard = self.saveDashboard(dashboard)
            await self.cacheVehicleImages(for: archivedDashboard)
            await self.refreshResolvedAddressesIfNeeded(for: archivedDashboard)
            await self.refreshAllVehicleInsights(using: client, dashboard: archivedDashboard)
            await self.autoAssociateRecordedRides(using: client, dashboard: archivedDashboard)
            self.errorMessage = nil
            self.statusMessage = "已更新 \(Self.timeFormatter.string(from: archivedDashboard.updatedAt))"
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func updateBatteryChemistry(
        sn: String,
        chemistry: NinebotBatteryChemistry,
        nominalVoltage: Double?,
        capacityWh: Double?
    ) async {
        await runLoadingOperation(message: "正在更新电池类型") {
            let client = try makeClient()
            _ = try await client.updateBatteryChemistry(
                sn: sn,
                chemistry: chemistry,
                nominalVoltage: nominalVoltage,
                capacityWh: capacityWh
            )
            let dashboard = try await client.fetchDashboard(selectedSN: sn)
            let archivedDashboard = self.saveDashboard(dashboard)
            await self.cacheVehicleImages(for: archivedDashboard)
            self.errorMessage = nil
            self.statusMessage = "已更新\(chemistry.title)电池参数"
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func insights(for sn: String) -> NinebotVehicleInsights? {
        vehicleInsights[sn]
    }

    func refreshVehicleInsights(sn: String) async {
        do {
            let client = try makeClient()
            vehicleInsights[sn] = try await client.fetchVehicleInsights(sn: sn)
            errorMessage = nil
        } catch {
            errorMessage = "服务器数据加载失败：\(error.localizedDescription)"
        }
    }

    func saveVehiclePreferences(
        sn: String,
        electricityPricePerKWh: Double?,
        ratedCapacityWh: Double?,
        lowBatteryEnabled: Bool,
        lowBatteryThreshold: Int
    ) async {
        await runLoadingOperation(message: "正在保存车辆设置") {
            let client = try makeClient()
            let chemistry = self.dashboard.vehicles
                .first(where: { $0.vehicle.sn == sn })?
                .state.serverPrediction?.batteryChemistry?.configured ?? .auto
            _ = try await client.updateBatteryChemistry(
                sn: sn,
                chemistry: chemistry,
                nominalVoltage: nil,
                capacityWh: ratedCapacityWh
            )
            _ = try await client.updateVehicleSettings(
                sn: sn,
                electricityPricePerKWh: electricityPricePerKWh,
                lowBatteryEnabled: lowBatteryEnabled,
                lowBatteryThreshold: lowBatteryThreshold,
                rangeCutoffPercent: self.dashboard.vehicles
                    .first(where: { $0.vehicle.sn == sn })
                    .map { Int($0.state.effectiveRangeCutoffPercent.rounded()) }
            )
            let dashboard = try await client.fetchDashboard(selectedSN: sn)
            let archivedDashboard = self.saveDashboard(dashboard)
            await self.cacheVehicleImages(for: archivedDashboard)
            self.vehicleInsights[sn] = try await client.fetchVehicleInsights(sn: sn)
            self.errorMessage = nil
            self.statusMessage = "车辆设置已保存，续航与充电统计已重新计算"
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func associateRecordedRide(_ record: NinebotRecordedRide, rideID: String?) async {
        await runLoadingOperation(message: rideID == nil ? "正在取消行程关联" : "正在关联并上传行程") {
            let client = try makeClient()
            if let rideID {
                guard let sn = record.vehicleSN else {
                    throw NinebotServerError.server("这条记录没有车辆信息")
                }
                _ = try await client.saveTravelLink(
                    sn: sn,
                    clientRecordID: record.id,
                    rideID: rideID,
                    startedAt: record.startedAt,
                    endedAt: record.endedAt,
                    mileageKM: record.distanceKilometers
                )
                self.vehicleInsights[sn] = try await client.fetchVehicleInsights(sn: sn)
            } else if let sn = record.vehicleSN, record.associatedRideID != nil {
                _ = try await client.deleteTravelLink(sn: sn, clientRecordID: record.id)
                self.vehicleInsights[sn] = try await client.fetchVehicleInsights(sn: sn)
            }

            var updated = record
            updated.associatedRideID = rideID
            self.store.upsertRecordedRide(updated)
            self.recordedRides = self.store.loadRecordedRides()
            self.errorMessage = nil
            self.statusMessage = rideID == nil ? "已取消行程关联" : "行程已关联并上传到服务器"
        }
    }

    func updateRangeCutoffPercent(sn: String, value: Double) {
        let clamped = min(max((value / 5).rounded() * 5, 5), 50)
        store.saveRangeCutoffPercent(clamped, sn: sn)

        var updated = dashboard
        if let index = updated.vehicles.firstIndex(where: { $0.vehicle.sn == sn }) {
            updated.vehicles[index].state.rangeCutoffPercent = clamped
        }
        _ = saveDashboard(updated)
        statusMessage = "续航已按 \(Int(clamped))% 截止电量重新估算"
        WidgetCenter.shared.reloadAllTimelines()

        Task {
            do {
                let client = try makeClient()
                _ = try await client.updateRangeCutoffPercent(
                    sn: sn,
                    percent: Int(clamped)
                )
            } catch {
                errorMessage = "截止电量已在本机保存，但同步服务器失败：\(error.localizedDescription)"
            }
        }
    }

    func syncTravelMonth(vehicleSN: String, month: String) async {
        await runLoadingOperation(message: "正在获取 \(Self.displayMonth(month)) 行程") {
            self.syncingTravelMonth = month
            defer { self.syncingTravelMonth = nil }

            let client = try makeClient()
            let page = try await client.syncTravelMonth(sn: vehicleSN, month: month, pageSize: 500)
            self.store.upsertInterfaceRideRecords(page.records, sn: vehicleSN)

            let dashboard = try await client.fetchDashboard(selectedSN: vehicleSN)
            let archivedDashboard = self.saveDashboard(dashboard)
            await self.cacheVehicleImages(for: archivedDashboard)
            await self.refreshResolvedAddressesIfNeeded(for: archivedDashboard)
            await self.autoAssociateRecordedRides(using: client, dashboard: archivedDashboard)

            if page.total == 0 {
                self.statusMessage = "\(Self.displayMonth(month)) 暂无行程"
            } else {
                self.statusMessage = "已获取 \(Self.displayMonth(month)) \(page.total) 条行程"
            }
            self.travelSyncDates["\(vehicleSN)|\(month)"] = Date()
            self.errorMessage = nil
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func autoSyncTravelMonthIfNeeded(vehicleSN: String, month: String) async {
        let key = "\(vehicleSN)|\(month)"
        if syncingTravelMonth == month {
            return
        }
        if let lastSyncedAt = travelSyncDates[key],
           Date().timeIntervalSince(lastSyncedAt) < 10 * 60 {
            return
        }
        await syncTravelMonth(vehicleSN: vehicleSN, month: month)
    }

    func resolveAddressesNow() async {
        await runLoadingOperation(message: "正在解析车辆位置") {
            try await self.resolveAddresses(for: self.dashboard, force: true)
            self.errorMessage = nil
            self.statusMessage = "车辆位置已解析"
        }
    }

    func enableChargingNotifications() async {
        await runLoadingOperation(message: "正在开启充电通知") {
            _ = try await NinebotPushManager.shared.requestAuthorizationRegisterAndWaitForToken()
            self.pushDeviceToken = self.store.loadPushDeviceToken()
            if self.pushDeviceToken != nil {
                try await NinebotPushManager.shared.registerStoredTokenWithServer()
                try? await NinebotPushManager.shared.registerStoredLiveActivityTokensWithServer()
                self.statusMessage = "充电通知已开启"
            } else {
                self.statusMessage = "已允许通知，系统返回设备 Token 后会自动上报"
            }
            self.errorMessage = nil
        }
    }

    func syncPushDeviceToken() async {
        await runLoadingOperation(message: "正在上报设备 Token") {
            _ = try await NinebotPushManager.shared.requestAuthorizationRegisterAndWaitForToken()
            self.pushDeviceToken = self.store.loadPushDeviceToken()
            try await NinebotPushManager.shared.registerStoredTokenWithServer()
            try? await NinebotPushManager.shared.registerStoredLiveActivityTokensWithServer()
            self.statusMessage = "设备 Token 已上报"
            self.errorMessage = nil
        }
    }

    func syncPushDeviceTokenIfPossible() async {
        guard hasConfiguration else { return }
        do {
            _ = try await NinebotPushManager.shared.requestAuthorizationRegisterAndWaitForToken()
            pushDeviceToken = store.loadPushDeviceToken()
            if pushDeviceToken != nil {
                try await NinebotPushManager.shared.registerStoredTokenWithServer()
            }
            try? await NinebotPushManager.shared.registerStoredLiveActivityTokensWithServer()
        } catch {
            // Token sync should not block normal app refresh; diagnostics can surface manual retry errors.
        }
    }

    func loginWithPassword() async {
        await runLoadingOperation(message: "正在密码登录") {
            guard !account.trimmed.isEmpty else { throw NinebotInputError.missingAccount }
            guard !password.isEmpty else { throw NinebotInputError.missingPassword }

            saveConfiguration()
            let client = try makeClient()
            let result = try await client.login(account: account.trimmed, password: password)
            rememberLoginResult(result, fallbackAccount: account.trimmed)
            password = ""
            await self.syncPushDeviceTokenIfPossible()

            let dashboard = try await makeClient().fetchDashboard(selectedSN: self.dashboard.selectedSN)
            let archivedDashboard = self.saveDashboard(dashboard)
            await self.cacheVehicleImages(for: archivedDashboard)
            await self.refreshResolvedAddressesIfNeeded(for: archivedDashboard)
            self.errorMessage = nil
            self.statusMessage = "登录成功"
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func selectVehicle(sn: String) {
        dashboard.selectedSN = sn
        saveDashboard(dashboard)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func perform(_ action: NinebotVehicleAction, sn: String) async {
        activeVehicleAction = action
        activeVehicleActionSN = sn
        defer {
            activeVehicleAction = nil
            activeVehicleActionSN = nil
        }

        await runLoadingOperation(message: action.loadingTitle) {
            let client = try makeClient()
            switch action {
            case .bell:
                _ = try await client.ringBell(sn: sn)
            case .openBucket:
                _ = try await client.openBucket(sn: sn)
            case .engineStart:
                _ = try await client.engineStart(sn: sn)
            case .engineStop:
                _ = try await client.engineStop(sn: sn)
            }

            self.statusMessage = action.resultTitle
            self.errorMessage = nil

            let dashboard = try await client.fetchDashboard(selectedSN: sn)
            let archivedDashboard = self.saveDashboard(dashboard)
            await self.cacheVehicleImages(for: archivedDashboard)
            await self.refreshResolvedAddressesIfNeeded(for: archivedDashboard)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func history(for sn: String) -> [NinebotVehicleHistoryPoint] {
        history[sn] ?? []
    }

    func recordedRides(for sn: String?) -> [NinebotRecordedRide] {
        recordedRides.filter { ride in
            guard let sn else { return true }
            return ride.vehicleSN == nil || ride.vehicleSN == sn
        }
    }

    func recordedRide(associatedWith rideID: String, vehicleSN: String?) -> NinebotRecordedRide? {
        recordedRides.first { ride in
            ride.associatedRideID == rideID && (vehicleSN == nil || ride.vehicleSN == nil || ride.vehicleSN == vehicleSN)
        }
    }

    func rideDetail(vehicleSN: String, rideID: String) -> NinebotRideDetail? {
        rideDetails[rideDetailKey(vehicleSN: vehicleSN, rideID: rideID)]
    }

    func isLoadingRideDetail(vehicleSN: String, rideID: String) -> Bool {
        loadingRideDetailKeys.contains(rideDetailKey(vehicleSN: vehicleSN, rideID: rideID))
    }

    func refreshRideDetail(vehicleSN: String, rideID: String, force: Bool = false) async {
        let key = rideDetailKey(vehicleSN: vehicleSN, rideID: rideID)
        guard force || rideDetails[key] == nil else { return }
        guard !loadingRideDetailKeys.contains(key) else { return }

        loadingRideDetailKeys.insert(key)
        defer {
            loadingRideDetailKeys.remove(key)
        }

        do {
            let client = try makeClient()
            let detail = try await client.fetchTravelDetail(sn: vehicleSN, travelID: rideID)
            rideDetails[key] = detail
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveRecordedRide(_ ride: NinebotRecordedRide) {
        store.upsertRecordedRide(ride)
        recordedRides = store.loadRecordedRides()
        statusMessage = "骑行记录已保存"
    }

    func deleteRecordedRide(id: String) {
        store.deleteRecordedRide(id: id)
        recordedRides = store.loadRecordedRides()
        statusMessage = "骑行记录已删除"
    }

    func resolvedAddressText(for snapshot: NinebotVehicleSnapshot) -> String? {
        return resolvedAddresses[snapshot.vehicle.sn]?.address
    }

    func clearMessages() {
        errorMessage = nil
        statusMessage = nil
    }

    func refreshCaches() async {
        store.clearServerCaches()
        history = [:]
        resolvedAddresses = [:]
        rideDetails = [:]
        loadingRideDetailKeys = []
        vehicleInsights = [:]
        lastAutomaticRefreshAt = nil

        guard hasConfiguration else {
            dashboard = .empty
            errorMessage = nil
            statusMessage = "缓存已刷新"
            return
        }

        await refreshDashboard()
    }

    func logoutCurrentAccount() {
        store.clearVehicleSessionData()
        NinebotChargingLiveActivityManager.sync(with: .empty)
        loginResult = nil
        account = ""
        password = ""
        dashboard = .empty
        history = [:]
        resolvedAddresses = [:]
        recordedRides = store.loadRecordedRides()
        rideDetails = [:]
        loadingRideDetailKeys = []
        syncingTravelMonth = nil
        vehicleInsights = [:]
        activeVehicleAction = nil
        activeVehicleActionSN = nil
        errorMessage = nil
        statusMessage = nil
        loadingMessage = nil
        isLoading = false
        lastAutomaticRefreshAt = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resetAllLocalData() {
        store.clearAllLocalData()
        NinebotChargingLiveActivityManager.sync(with: .empty)
        baseURLString = ""
        bearerToken = ""
        account = ""
        password = ""
        pushDeviceToken = nil
        loginResult = nil
        dashboard = .empty
        history = [:]
        resolvedAddresses = [:]
        recordedRides = []
        rideDetails = [:]
        loadingRideDetailKeys = []
        syncingTravelMonth = nil
        vehicleInsights = [:]
        capturePrivacyProtectionEnabled = false
        activeVehicleAction = nil
        activeVehicleActionSN = nil
        errorMessage = nil
        statusMessage = nil
        loadingMessage = nil
        isLoading = false
        lastAutomaticRefreshAt = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setCapturePrivacyProtectionEnabled(_ isEnabled: Bool) {
        capturePrivacyProtectionEnabled = isEnabled
        store.saveCapturePrivacyProtectionEnabled(isEnabled)
        statusMessage = isEnabled ? "截图录屏保护已开启" : "截图录屏保护已关闭"
        errorMessage = nil
    }

    func diagnosticsSnapshot() -> NinebotDiagnosticsSnapshot {
        let vehicles = dashboard.vehicles
        let interfaceRideCount = vehicles.reduce(0) { count, snapshot in
            count + store.interfaceRideCount(sn: snapshot.vehicle.sn)
        }
        let historyPointCount = vehicles.reduce(0) { count, snapshot in
            count + store.historyCount(sn: snapshot.vehicle.sn)
        }

        return NinebotDiagnosticsSnapshot(
            hasConfiguration: hasConfiguration,
            serverText: diagnosticsConnectionText,
            accountText: currentAccountDisplay,
            vehicleCount: vehicles.count,
            selectedVehicleName: dashboard.primaryVehicle?.vehicle.name ?? "暂无车辆",
            dashboardUpdatedAt: dashboard.updatedAt == .distantPast ? nil : dashboard.updatedAt,
            lastAppRefreshEvent: store.loadLastAppRefreshEvent(),
            lastWidgetRefreshEvent: store.loadLastWidgetRefreshEvent(),
            lastError: errorMessage ?? store.loadLastError(),
            interfaceRideCount: interfaceRideCount,
            historyPointCount: historyPointCount,
            recordedRideCount: store.recordedRideCount(),
            rideDetailCount: rideDetails.count,
            resolvedAddressCount: resolvedAddresses.count,
            dashboardCacheBytes: store.storedDashboardByteCount()
        )
    }

    private var currentConfiguration: NinebotServerConfiguration {
        NinebotServerConfiguration(
            baseURLString: baseURLString,
            bearerToken: bearerToken,
            appSessionToken: loginResult?.sessionToken
        )
    }

    private var diagnosticsConnectionText: String {
        baseURLString.trimmed.isEmpty ? "服务器未配置" : "服务器 · \(baseURLString.trimmed)"
    }

    private func makeClient() throws -> NinebotServerClient {
        let configuration = currentConfiguration
        guard configuration.isUsable else {
            throw NinebotInputError.missingServer
        }
        store.saveConfiguration(configuration)
        return NinebotServerClient(configuration: configuration)
    }

    private func refreshAllVehicleInsights(
        using client: NinebotServerClient,
        dashboard: NinebotDashboard
    ) async {
        var updatedDashboard = dashboard
        var didChangeRangeCutoff = false
        for snapshot in dashboard.vehicles {
            do {
                let insights = try await client.fetchVehicleInsights(
                    sn: snapshot.vehicle.sn
                )
                vehicleInsights[snapshot.vehicle.sn] = insights
                if let cutoff = insights.vehicleSettings["range_cutoff_percent"]?.doubleValue,
                   let index = updatedDashboard.vehicles.firstIndex(where: {
                       $0.vehicle.sn == snapshot.vehicle.sn
                   }) {
                    let clamped = min(max(cutoff.rounded(), 5), 50)
                    store.saveRangeCutoffPercent(clamped, sn: snapshot.vehicle.sn)
                    if updatedDashboard.vehicles[index].state.rangeCutoffPercent != clamped {
                        updatedDashboard.vehicles[index].state.rangeCutoffPercent = clamped
                        didChangeRangeCutoff = true
                    }
                } else {
                    _ = try? await client.updateRangeCutoffPercent(
                        sn: snapshot.vehicle.sn,
                        percent: Int(snapshot.state.effectiveRangeCutoffPercent.rounded())
                    )
                }
            } catch {
                continue
            }
        }
        if didChangeRangeCutoff {
            _ = saveDashboard(updatedDashboard)
        }
    }

    private func autoAssociateRecordedRides(
        using client: NinebotServerClient,
        dashboard: NinebotDashboard
    ) async {
        let rides = dashboard.vehicles.flatMap { snapshot in
            snapshot.state.rides.map { (vehicleSN: snapshot.vehicle.sn, ride: $0) }
        }
        guard !rides.isEmpty else { return }

        var records = store.loadRecordedRides()
        var usedRideIDs = Set(records.compactMap(\.associatedRideID))
        var associatedCount = 0

        for index in records.indices {
            guard records[index].associatedRideID == nil else { continue }
            let record = records[index]
            var bestVehicleSN: String?
            var bestRide: NinebotRideRecord?
            var bestScore = 0.0
            var secondBestScore = 0.0

            for candidate in rides {
                if let vehicleSN = record.vehicleSN, vehicleSN != candidate.vehicleSN {
                    continue
                }
                if usedRideIDs.contains(candidate.ride.id) {
                    continue
                }
                guard let score = Self.rideMatchScore(record: record, ride: candidate.ride) else {
                    continue
                }
                if score > bestScore {
                    secondBestScore = bestScore
                    bestScore = score
                    bestRide = candidate.ride
                    bestVehicleSN = candidate.vehicleSN
                } else if score > secondBestScore {
                    secondBestScore = score
                }
            }

            guard let bestRide, let bestVehicleSN,
                  bestScore >= 0.76,
                  bestScore - secondBestScore >= 0.08 else {
                continue
            }

            do {
                _ = try await client.saveTravelLink(
                    sn: bestVehicleSN,
                    clientRecordID: record.id,
                    rideID: bestRide.id,
                    startedAt: record.startedAt,
                    endedAt: record.endedAt,
                    mileageKM: record.distanceKilometers
                )
                records[index].vehicleSN = bestVehicleSN
                records[index].associatedRideID = bestRide.id
                usedRideIDs.insert(bestRide.id)
                associatedCount += 1
            } catch {
                continue
            }
        }

        guard associatedCount > 0 else { return }
        for record in records where record.associatedRideID != nil {
            if let existing = recordedRides.first(where: { $0.id == record.id }),
               existing != record {
                store.upsertRecordedRide(record)
            } else if !recordedRides.contains(where: { $0.id == record.id }) {
                store.upsertRecordedRide(record)
            }
        }
        recordedRides = store.loadRecordedRides()
        statusMessage = "已自动关联 \(associatedCount) 条本地行程"
    }

    private static func rideMatchScore(
        record: NinebotRecordedRide,
        ride: NinebotRideRecord
    ) -> Double? {
        guard let rideStart = ride.startedAt,
              let rideEnd = ride.endedAt,
              let rideMileage = ride.mileage,
              rideMileage > 0.15 else {
            return nil
        }

        let startDelta = abs(record.startedAt.timeIntervalSince(rideStart))
        let endDelta = abs(record.endedAt.timeIntervalSince(rideEnd))
        guard startDelta <= 15 * 60, endDelta <= 20 * 60 else { return nil }

        let overlap = max(
            min(record.endedAt, rideEnd).timeIntervalSince(max(record.startedAt, rideStart)),
            0
        )
        let shorterDuration = max(
            min(record.durationSeconds, rideEnd.timeIntervalSince(rideStart)),
            1
        )
        let overlapRatio = min(overlap / shorterDuration, 1)
        guard overlapRatio >= 0.55 else { return nil }

        let mileageDelta = abs(record.distanceKilometers - rideMileage)
        let mileageTolerance = max(0.45, rideMileage * 0.28)
        guard mileageDelta <= mileageTolerance else { return nil }
        let mileageScore = min(max(1 - mileageDelta / mileageTolerance, 0), 1)

        let durationDelta = abs(
            record.durationSeconds - rideEnd.timeIntervalSince(rideStart)
        )
        let durationTolerance = max(
            max(record.durationSeconds, rideEnd.timeIntervalSince(rideStart)),
            60
        )
        let durationScore = min(max(1 - durationDelta / durationTolerance, 0), 1)

        return overlapRatio * 0.58 + mileageScore * 0.30 + durationScore * 0.12
    }

    private func rideDetailKey(vehicleSN: String, rideID: String) -> String {
        "\(vehicleSN)|\(rideID)"
    }

    @discardableResult
    private func saveDashboard(_ dashboard: NinebotDashboard) -> NinebotDashboard {
        let archivedDashboard = store.saveDashboard(dashboard)
        self.dashboard = archivedDashboard
        history = Self.historyMap(for: archivedDashboard, store: store)
        NinebotChargingLiveActivityManager.sync(with: archivedDashboard)
        return archivedDashboard
    }

    private func refreshResolvedAddressesIfNeeded(for dashboard: NinebotDashboard) async {
        try? await resolveAddresses(for: dashboard, force: false)
    }

    private func cacheVehicleImages(for dashboard: NinebotDashboard) async {
        for snapshot in dashboard.vehicles {
            guard let urlString = snapshot.vehicle.imageURLString?.trimmed,
                  !urlString.isEmpty,
                  let url = URL(string: urlString) else {
                continue
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      !data.isEmpty,
                      data.count <= 2_500_000 else {
                    continue
                }
                store.saveVehicleImageData(data, sn: snapshot.vehicle.sn)
            } catch {
                continue
            }
        }
    }

    private func resolveAddresses(for dashboard: NinebotDashboard, force: Bool) async throws {
        let geocoder = AppleReverseGeocoder()
        var nextAddresses = resolvedAddresses
        var didResolve = false
        var lastError: Error?
        var sawCoordinate = false

        for snapshot in dashboard.vehicles {
            guard let latitude = snapshot.state.latitude,
                  let longitude = snapshot.state.longitude else {
                continue
            }

            sawCoordinate = true
            if !force, let cached = nextAddresses[snapshot.vehicle.sn],
               isFreshAddress(cached, latitude: latitude, longitude: longitude) {
                continue
            }

            do {
                let geocodeCoordinate = NinebotCoordinateTransform.gcj02Coordinate(latitude: latitude, longitude: longitude)
                let address = try await geocoder.reverseGeocode(
                    latitude: geocodeCoordinate.latitude,
                    longitude: geocodeCoordinate.longitude
                )
                nextAddresses[snapshot.vehicle.sn] = NinebotResolvedAddress(
                    sn: snapshot.vehicle.sn,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    updatedAt: Date(),
                    source: Self.addressGeocodingSource
                )
                didResolve = true
            } catch {
                lastError = error
            }
        }

        resolvedAddresses = nextAddresses
        store.saveResolvedAddresses(nextAddresses)

        if force, !didResolve {
            if let lastError {
                throw lastError
            }
            if !sawCoordinate {
                throw AppleGeocodingError.missingCoordinate
            }
        }
    }

    private func isFreshAddress(
        _ address: NinebotResolvedAddress,
        latitude: Double,
        longitude: Double
    ) -> Bool {
        let sameCoordinate = abs(address.latitude - latitude) < 0.00001
            && abs(address.longitude - longitude) < 0.00001
        return sameCoordinate && Date().timeIntervalSince(address.updatedAt) < 15 * 60
    }

    private func rememberLoginResult(_ result: NinebotLoginResult, fallbackAccount: String) {
        var resolvedResult = result
        if resolvedResult.phone?.trimmed.isEmpty != false {
            resolvedResult.phone = fallbackAccount
        }
        loginResult = resolvedResult
        account = resolvedResult.phone ?? fallbackAccount
        store.saveLoginResult(resolvedResult)
        store.saveConfiguration(currentConfiguration)
    }

    private func runLoadingOperation(message: String, _ operation: () async throws -> Void) async {
        let startedAt = Date()
        loadingMessage = message
        isLoading = true

        do {
            try await operation()
            store.saveLastAppRefreshEvent(NinebotRefreshEvent(
                source: "App",
                operation: message,
                startedAt: startedAt,
                endedAt: Date(),
                success: true,
                message: statusMessage
            ))
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            statusMessage = nil
            store.saveLastError(message)
            store.saveLastAppRefreshEvent(NinebotRefreshEvent(
                source: "App",
                operation: self.loadingMessage ?? "操作",
                startedAt: startedAt,
                endedAt: Date(),
                success: false,
                message: message
            ))
        }

        isLoading = false
        loadingMessage = nil
    }

    private static func displayMonth(_ month: String) -> String {
        guard month.count == 6 else { return month }
        let year = month.prefix(4)
        let monthValue = month.suffix(2)
        return "\(year)年\(monthValue)月"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let addressGeocodingSource = "apple-mapkit"

    private static func historyMap(
        for dashboard: NinebotDashboard,
        store: NinebotSharedStore
    ) -> [String: [NinebotVehicleHistoryPoint]] {
        Dictionary(uniqueKeysWithValues: dashboard.vehicles.map { snapshot in
            (snapshot.vehicle.sn, store.loadHistory(sn: snapshot.vehicle.sn))
        })
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum AppleGeocodingError: LocalizedError {
    case invalidResponse
    case missingCoordinate

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Apple 地址解析返回无效"
        case .missingCoordinate:
            return "车辆暂未返回可解析的坐标"
        }
    }
}

private struct AppleReverseGeocoder {
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            throw AppleGeocodingError.invalidResponse
        }
        request.preferredLocale = Locale(identifier: "zh_CN")

        let mapItems = try await request.mapItems
        let address = Self.addressText(from: mapItems.first)
        guard !address.isEmpty else {
            throw AppleGeocodingError.invalidResponse
        }
        return address
    }

    private static func addressText(from mapItem: MKMapItem?) -> String {
        guard let mapItem else { return "" }
        let candidates = [
            mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true),
            mapItem.address?.fullAddress,
            mapItem.address?.shortAddress,
            mapItem.name
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }
}
