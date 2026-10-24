import Foundation
import SwiftUI
import UIKit

struct NinebotSettingsView: View {
    @ObservedObject var model: NinebotViewModel
    @Environment(\.openURL) private var openURL
    @State private var isShowingConnectionSettings = false

    var body: some View {
        Group {
            if model.hasLoginAccount {
                settingsContent
            } else {
                NinebotLoginPage(model: model)
            }
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                SettingsProfileCard(
                    snapshot: model.dashboard.primaryVehicle,
                    accountText: model.currentAccountDisplay,
                    vehicleCount: model.dashboard.vehicles.count
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .ninePlusCard(cornerRadius: 28)

                if let snapshot = model.dashboard.primaryVehicle {
                    RangeCutoffSettingsCard(model: model, snapshot: snapshot)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .ninePlusCard(cornerRadius: 24)

                    VehiclePreferencesSettingsCard(model: model, snapshot: snapshot)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .ninePlusCard(cornerRadius: 24)
                }

                if model.errorMessage != nil || model.statusMessage != nil {
                    SettingsStatusBanner(
                        errorMessage: model.errorMessage,
                        statusMessage: model.statusMessage
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .ninePlusCard(cornerRadius: 24)
                }

                DisclosureGroup(isExpanded: $isShowingConnectionSettings) {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()

                        SettingsInputField(
                            title: "服务器地址",
                            placeholder: "http://服务器IP:19009",
                            systemImage: "cloud.fill",
                            text: $model.baseURLString,
                            keyboardType: .URL,
                            textContentType: .URL
                        )

                        SettingsInputField(
                            title: "访问口令（可选）",
                            placeholder: "后台设置了 App Bearer Token 时填写",
                            systemImage: "key.horizontal.fill",
                            text: $model.bearerToken,
                            isSecure: true
                        )

                        HStack(spacing: 10) {
                            Button {
                                isShowingConnectionSettings = false
                            } label: {
                                SettingsCompactButtonLabel(title: "收起", systemImage: "chevron.up")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                Task { await model.testConnection() }
                            } label: {
                                SettingsCompactButtonLabel(title: "测试", systemImage: "network")
                            }
                            .buttonStyle(.bordered)
                            .disabled(!hasText(model.baseURLString))

                            Button {
                                saveConnection()
                            } label: {
                                SettingsCompactButtonLabel(title: "保存", systemImage: "tray.and.arrow.down.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!hasText(model.baseURLString))
                        }
                        .font(.subheadline.weight(.semibold))

                        Text("多账号、APNs 和轮询策略在 NinePlus Platform 后台管理；后台未设置 App Bearer Token 时可留空。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        PushDeviceTokenRow(token: model.pushDeviceToken, hasConfiguration: model.hasConfiguration)

                        Button {
                            Task { await model.enableChargingNotifications() }
                        } label: {
                            SettingsButtonLabel(title: "检查权限并上报", systemImage: "bell.badge.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.hasConfiguration)

                        Button {
                            Task { await model.syncPushDeviceToken() }
                        } label: {
                            SettingsButtonLabel(title: "重新上报设备", systemImage: "arrow.up.doc.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!model.hasConfiguration)
                    }
                    .padding(.top, 8)
                } label: {
                    SettingsNavigationRow(
                        title: "连接与通知",
                        subtitle: connectionSummaryText,
                        systemImage: "cloud.fill",
                        tint: model.hasConfiguration ? .green : .orange
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .ninePlusCard(cornerRadius: 24)

                NavigationLink {
                    NinebotDiagnosticsView(model: model)
                } label: {
                    SettingsNavigationRow(
                        title: "诊断中心",
                        subtitle: "刷新、缓存、Widget 和原始字段",
                        systemImage: "stethoscope"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(16)
                .ninePlusCard(cornerRadius: 24)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Siri 与快捷指令")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.teslaPrimaryText)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        SettingsButtonLabel(title: "打开 Siri 设置", systemImage: "mic.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    VStack(spacing: 10) {
                        ShortcutCapabilityRow(title: "刷新车况", systemImage: "arrow.clockwise")
                        ShortcutCapabilityRow(title: "查询电量", systemImage: "battery.100")
                        ShortcutCapabilityRow(title: "查询位置", systemImage: "location.fill")
                        ShortcutCapabilityRow(title: "寻车铃", systemImage: "bell.fill")
                        ShortcutCapabilityRow(title: "打开座桶", systemImage: "shippingbox.fill")
                        ShortcutCapabilityRow(title: "上电", systemImage: "power.circle.fill")
                        ShortcutCapabilityRow(title: "熄火", systemImage: "lock.fill")
                    }
                    .padding(12)
                    .background(Color.teslaControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .ninePlusCard(cornerRadius: 24)
            }
            .padding(16)
            .padding(.bottom, 18)
        }
        .disabled(model.isLoading)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.teslaPageBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func hasText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var connectionSummaryText: String {
        if model.hasConfiguration {
            return "服务器已配置 · \(model.pushDeviceToken == nil ? "APNs 未上报" : "APNs 已就绪")"
        }
        return "配置服务器与通知上报"
    }

    private func saveConnection() {
        model.saveConfiguration()
        if model.hasConfiguration {
            isShowingConnectionSettings = false
            Task { await model.syncPushDeviceTokenIfPossible() }
        }
    }
}

private struct RangeCutoffSettingsCard: View {
    @ObservedObject var model: NinebotViewModel
    var snapshot: NinebotVehicleSnapshot
    @State private var cutoff: Double
    @State private var isExpanded = false

    init(model: NinebotViewModel, snapshot: NinebotVehicleSnapshot) {
        self.model = model
        self.snapshot = snapshot
        _cutoff = State(initialValue: snapshot.state.effectiveRangeCutoffPercent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.teslaGreen.opacity(0.12))
                        Image(systemName: "road.lanes")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.teslaGreen)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("可用续航预估")
                            .font(.headline)
                            .foregroundStyle(Color.teslaPrimaryText)
                        Text("截止 \(Int(cutoff))% · \(snapshot.state.localEstimatedMileageText)")
                            .font(.caption)
                            .foregroundStyle(Color.teslaSecondaryText)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.teslaSecondaryText)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack {
                    Text("截止电量")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.teslaPrimaryText)
                    Spacer()
                    Text("\(Int(cutoff))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.teslaGreen)
                }

                Slider(value: $cutoff, in: 5...50, step: 5)
                    .tint(Color.teslaGreen)
                    .disabled(model.isLoading)

                HStack(spacing: 6) {
                    Text("5%")
                    Spacer()
                    Text("20% 推荐")
                    Spacer()
                    Text("50%")
                }
                .font(.caption2)
                .foregroundStyle(Color.teslaSecondaryText)

                Text(snapshot.state.rangeCutoffSummaryText)
                    .font(.caption)
                    .foregroundStyle(Color.teslaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Label(snapshot.state.rangeEstimateAccuracyDetailText, systemImage: "chart.bar.doc.horizontal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.teslaSecondaryText)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Button("恢复 20%") {
                        cutoff = 20
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .disabled(model.isLoading || cutoff == 20)
                }
            }
        }
        .onChange(of: cutoff) { _, value in
            model.updateRangeCutoffPercent(sn: snapshot.vehicle.sn, value: value)
        }
        .onChange(of: snapshot.state.effectiveRangeCutoffPercent) { _, value in
            if abs(cutoff - value) >= 0.1 {
                cutoff = value
            }
        }
    }
}

private struct VehiclePreferencesSettingsCard: View {
    @ObservedObject var model: NinebotViewModel
    var snapshot: NinebotVehicleSnapshot
    @State private var electricityPriceText = ""
    @State private var ratedCapacityText = ""
    @State private var lowBatteryEnabled = false
    @State private var lowBatteryThreshold = 20.0
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bolt.batteryblock.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.teslaGreen)
                        .frame(width: 42, height: 42)
                        .background(Color.teslaGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("充电与低电量预警")
                            .font(.headline)
                            .foregroundStyle(Color.teslaPrimaryText)
                        Text(compactSummaryText)
                            .font(.caption)
                            .foregroundStyle(Color.teslaSecondaryText)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.teslaSecondaryText)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    SettingsInputField(
                        title: "额定容量",
                        placeholder: "例如 2808",
                        systemImage: "battery.100",
                        text: $ratedCapacityText,
                        keyboardType: .decimalPad
                    )
                    SettingsInputField(
                        title: "电价（元/kWh）",
                        placeholder: "例如 0.60",
                        systemImage: "yensign.circle.fill",
                        text: $electricityPriceText,
                        keyboardType: .decimalPad
                    )
                }

                HStack {
                    Toggle("低电量预警", isOn: $lowBatteryEnabled)
                        .tint(Color.teslaGreen)
                    Spacer(minLength: 12)
                    Text("\(Int(lowBatteryThreshold))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.teslaGreen)
                }

                Slider(value: $lowBatteryThreshold, in: 5...50, step: 5)
                    .tint(Color.teslaGreen)
                    .disabled(!lowBatteryEnabled)

                Text("达到阈值时由服务器通过 Bark 推送一次，电量回升后会自动重新布防。")
                    .font(.caption)
                    .foregroundStyle(Color.teslaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if ratedCapacityValue == nil, !ratedCapacityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("额定容量需在 80–10000 Wh 之间", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button {
                    Task {
                        await model.saveVehiclePreferences(
                            sn: snapshot.vehicle.sn,
                            electricityPricePerKWh: electricityPriceValue,
                            ratedCapacityWh: ratedCapacityValue,
                            lowBatteryEnabled: lowBatteryEnabled,
                            lowBatteryThreshold: Int(lowBatteryThreshold)
                        )
                    }
                } label: {
                    HStack {
                        if model.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("保存车辆设置")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.teslaGreen)
                .disabled(model.isLoading || !isValidInput)
            }
        }
        .task(id: snapshot.vehicle.sn) {
            if model.insights(for: snapshot.vehicle.sn) == nil {
                await model.refreshVehicleInsights(sn: snapshot.vehicle.sn)
            }
            applyServerSettings()
        }
        .onChange(of: model.vehicleInsights[snapshot.vehicle.sn]) { _, _ in
            applyServerSettings()
        }
    }

    private var compactSummaryText: String {
        var parts: [String] = []
        if let capacity = ratedCapacityValue {
            parts.append("\(Int(capacity)) Wh")
        } else {
            parts.append("容量未设置")
        }
        if let price = electricityPriceValue {
            parts.append(String(format: "¥%.2f/kWh", price))
        }
        parts.append(lowBatteryEnabled ? "低电量 \(Int(lowBatteryThreshold))%" : "低电量预警关闭")
        return parts.joined(separator: " · ")
    }

    private var electricityPriceValue: Double? {
        let trimmed = electricityPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private var ratedCapacityValue: Double? {
        let trimmed = ratedCapacityText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              80...10000 ~= value else {
            return nil
        }
        return value
    }

    private var isValidInput: Bool {
        let capacityIsBlank = ratedCapacityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let priceIsBlank = electricityPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let priceValid = priceIsBlank
            || electricityPriceValue.map { (0...20).contains($0) } == true
        return (capacityIsBlank || ratedCapacityValue != nil) && priceValid
    }

    private func applyServerSettings() {
        guard let insights = model.insights(for: snapshot.vehicle.sn) else { return }
        electricityPriceText = Self.inputText(
            insights.vehicleSettings["electricity_price_per_kwh"]?.doubleValue
        )
        lowBatteryEnabled = insights.vehicleSettings["low_battery_enabled"]?.boolValue ?? false
        lowBatteryThreshold = Double(
            insights.vehicleSettings["low_battery_threshold"]?.intValue ?? 20
        )
        ratedCapacityText = Self.inputText(
            insights.batterySettings?["capacity_wh"]?.doubleValue
        )
    }

    private static func inputText(_ value: Double?) -> String {
        guard let value else { return "" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

private enum LoginFocusField: Hashable {
    case phone
    case password
}

private struct NinebotLoginPage: View {
    @ObservedObject var model: NinebotViewModel
    @FocusState private var focusedField: LoginFocusField?
    @State private var isShowingConnectionSheet = false
    @State private var isAgreementAccepted = false
    @State private var isPasswordVisible = false
    @State private var toastMessage: String?
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            loginBackground
                .ignoresSafeArea()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        LoginHeroVisual()

                        VStack(spacing: 18) {
                            VStack(spacing: 12) {
                                LoginInputRow(
                                    placeholder: "请输入手机号",
                                    systemImage: "iphone",
                                    text: $model.account,
                                    focusedField: $focusedField,
                                    field: .phone,
                                    keyboardType: .phonePad,
                                    textContentType: .telephoneNumber
                                )
                                .id(LoginFocusField.phone)

                                passwordInput
                            }

                            LoginAgreementRow(isAccepted: $isAgreementAccepted)

                            Button {
                                submitLogin()
                            } label: {
                                HStack(spacing: 8) {
                                    if model.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text("登录")
                                        .font(.headline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(.white)
                                .background(canSubmit ? Color.loginPrimaryControl : Color.loginDisabled)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSubmit || model.isLoading)
                            .animation(.easeInOut(duration: 0.18), value: canSubmit)
                        }
                        .padding(18)
                        .background(Color.loginCard)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: Color.black.opacity(0.055), radius: 24, x: 0, y: 16)
                        .padding(.horizontal, 22)
                        .offset(y: keyboardHeight > 0 ? -34 : -28)
                    }
                    .padding(.bottom, keyboardHeight > 0 ? 160 : 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { _, field in
                    scrollToFocusedField(field, using: scrollProxy)
                }
                .onChange(of: keyboardHeight) { _, height in
                    guard height > 0 else { return }
                    scrollToFocusedField(focusedField, using: scrollProxy)
                }
            }

            HStack {
                Spacer()
                Button {
                    isShowingConnectionSheet = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.loginInk)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .accessibilityLabel("连接设置")
                .padding(.trailing, 18)
                .padding(.top, 10)
            }

            if let toastMessage {
                LoginToast(message: toastMessage)
                    .padding(.top, 62)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .sheet(isPresented: $isShowingConnectionSheet) {
            LoginConnectionSheet(model: model)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) {
                keyboardHeight = 0
            }
        }
    }

    @ViewBuilder
    private var passwordInput: some View {
        LoginInputRow(
            placeholder: "请输入密码",
            systemImage: "lock.fill",
            text: $model.password,
            focusedField: $focusedField,
            field: .password,
            isSecure: !isPasswordVisible,
            textContentType: .password
        ) {
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.loginMuted)
                    .frame(width: 30)
            }
        }
        .id(LoginFocusField.password)
    }

    private var loginBackground: some View {
        LinearGradient(
            colors: [
                Color.loginBackgroundTop,
                Color.loginBackgroundBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var phoneDigits: String {
        model.account.filter(\.isNumber)
    }

    private var isPhoneValid: Bool {
        phoneDigits.count == 11 && phoneDigits.first == "1"
    }

    private var isPasswordValid: Bool {
        model.password.count >= 6
    }

    private var canSubmit: Bool {
        isAgreementAccepted && isPhoneValid && isPasswordValid
    }

    private func submitLogin() {
        guard model.hasConfiguration else {
            showToast("请先设置连接地址")
            isShowingConnectionSheet = true
            return
        }
        guard isPhoneValid else {
            showToast("请输入正确的手机号")
            focusedField = .phone
            return
        }
        guard isAgreementAccepted else {
            showToast("请先勾选用户协议")
            return
        }
        guard isPasswordValid else {
            showToast("密码至少 6 位")
            focusedField = .password
            return
        }

        Task {
            await model.loginWithPassword()
            if let error = model.errorMessage {
                showToast(error)
            } else {
                showToast("登录成功")
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let screenHeight = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
            .max() ?? frame.maxY
        let height = max(0, screenHeight - frame.minY)
        withAnimation(.easeOut(duration: 0.22)) {
            keyboardHeight = height
        }
    }

    private func scrollToFocusedField(_ field: LoginFocusField?, using proxy: ScrollViewProxy) {
        guard let field else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
    }
}

private struct LoginConnectionSheet: View {
    @ObservedObject var model: NinebotViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("连接设置")
                        .font(.title2.weight(.semibold))
                    Text("接口地址由用户自行填写；后台设置了 App 访问口令时再填口令。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsInputField(
                    title: "服务器地址",
                    placeholder: "http://服务器IP:19009",
                    systemImage: "cloud.fill",
                    text: $model.baseURLString,
                    keyboardType: .URL,
                    textContentType: .URL
                )

                SettingsInputField(
                    title: "访问口令（可选）",
                    placeholder: "后台设置了 App Bearer Token 时填写",
                    systemImage: "key.horizontal.fill",
                    text: $model.bearerToken,
                    isSecure: true
                )

                HStack(spacing: 10) {
                    Button {
                        Task { await model.testConnection() }
                    } label: {
                        SettingsCompactButtonLabel(title: "测试", systemImage: "network")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        model.saveConfiguration()
                        if model.hasConfiguration {
                            dismiss()
                            Task { await model.syncPushDeviceTokenIfPossible() }
                        }
                    } label: {
                        SettingsCompactButtonLabel(title: "保存", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color.teslaPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

}

private struct LoginHeroVisual: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.loginHeroTop,
                            Color.loginHeroBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.loginHeroOrb)
                .frame(width: 220, height: 220)
                .offset(x: 70, y: -36)

            Image("LoginVehicle")
                .resizable()
                .scaledToFit()
                .frame(width: 230, height: 170)
                .offset(x: 36, y: 26)
                .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 12)

            VStack(spacing: 10) {
                NinePlusLoginLogo()
                VStack(spacing: 5) {
                    Text("欢迎登录")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.loginInk)
                    Text("开启智能出行新体验")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.loginMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 96)
        }
        .frame(height: 292)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 22, x: 0, y: 12)
        .padding(.horizontal, 22)
        .padding(.top, 26)
    }
}

private struct NinePlusLoginLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.loginPrimaryControl)
            Image(systemName: "bolt.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(width: 58, height: 58)
        .shadow(color: Color.loginPrimaryControl.opacity(0.18), radius: 16, x: 0, y: 8)
        .accessibilityLabel("NineBot+")
    }
}

private struct LoginInputRow<Trailing: View>: View {
    var placeholder: String
    var systemImage: String
    @Binding var text: String
    @FocusState.Binding var focusedField: LoginFocusField?
    var field: LoginFocusField
    var isSecure = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var trailing: Trailing

    init(
        placeholder: String,
        systemImage: String,
        text: Binding<String>,
        focusedField: FocusState<LoginFocusField?>.Binding,
        field: LoginFocusField,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.placeholder = placeholder
        self.systemImage = systemImage
        self._text = text
        self._focusedField = focusedField
        self.field = field
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isFocused ? Color.loginAccent : Color.loginMuted)
                .frame(width: 24)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .focused($focusedField, equals: field)
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body.weight(.medium))
            .foregroundStyle(Color.loginInk)

            trailing
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.loginField)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isFocused ? Color.loginAccent : Color.loginBorder, lineWidth: isFocused ? 1.5 : 1)
        }
        .animation(.easeInOut(duration: 0.16), value: isFocused)
    }

    private var isFocused: Bool {
        focusedField == field
    }
}

private extension LoginInputRow where Trailing == EmptyView {
    init(
        placeholder: String,
        systemImage: String,
        text: Binding<String>,
        focusedField: FocusState<LoginFocusField?>.Binding,
        field: LoginFocusField,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil
    ) {
        self.init(
            placeholder: placeholder,
            systemImage: systemImage,
            text: text,
            focusedField: focusedField,
            field: field,
            isSecure: isSecure,
            keyboardType: keyboardType,
            textContentType: textContentType
        ) {
            EmptyView()
        }
    }
}

private struct LoginAgreementRow: View {
    @Binding var isAccepted: Bool

    var body: some View {
        Button {
            isAccepted.toggle()
        } label: {
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: isAccepted ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isAccepted ? Color.loginAccent : Color.loginBorder)

                Text("我已阅读并同意《用户协议》和《隐私政策》")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.loginMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LoginToast: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.loginToastBackground)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
    }
}

private extension Color {
    static let loginInk = loginDynamic(
        light: UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1)
    )
    static let loginMuted = loginDynamic(
        light: UIColor(red: 0.48, green: 0.51, blue: 0.58, alpha: 1),
        dark: UIColor(red: 0.64, green: 0.67, blue: 0.72, alpha: 1)
    )
    static let loginAccent = loginDynamic(
        light: UIColor(red: 0.13, green: 0.40, blue: 0.86, alpha: 1),
        dark: UIColor(red: 0.33, green: 0.62, blue: 1.00, alpha: 1)
    )
    static let loginPrimaryControl = loginDynamic(
        light: UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.72, blue: 0.30, alpha: 1)
    )
    static let loginDisabled = loginDynamic(
        light: UIColor(red: 0.72, green: 0.74, blue: 0.79, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1)
    )
    static let loginSoftControl = loginDynamic(
        light: UIColor(red: 0.91, green: 0.93, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1)
    )
    static let loginCard = loginDynamic(
        light: UIColor.white,
        dark: UIColor(red: 0.075, green: 0.08, blue: 0.092, alpha: 1)
    )
    static let loginField = loginDynamic(
        light: UIColor(red: 0.975, green: 0.98, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1)
    )
    static let loginBorder = loginDynamic(
        light: UIColor(red: 0.84, green: 0.86, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.27, green: 0.29, blue: 0.33, alpha: 1)
    )
    static let loginBackgroundTop = loginDynamic(
        light: UIColor(red: 0.96, green: 0.975, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.041, blue: 0.052, alpha: 1)
    )
    static let loginBackgroundBottom = loginDynamic(
        light: UIColor(red: 0.985, green: 0.988, blue: 0.994, alpha: 1),
        dark: UIColor(red: 0.018, green: 0.021, blue: 0.027, alpha: 1)
    )
    static let loginHeroTop = loginDynamic(
        light: UIColor.white.withAlphaComponent(0.98),
        dark: UIColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 1)
    )
    static let loginHeroBottom = loginDynamic(
        light: UIColor(red: 0.90, green: 0.94, blue: 0.99, alpha: 0.86),
        dark: UIColor(red: 0.055, green: 0.14, blue: 0.10, alpha: 1)
    )
    static let loginHeroOrb = loginDynamic(
        light: UIColor.white.withAlphaComponent(0.64),
        dark: UIColor(red: 0.13, green: 0.28, blue: 0.18, alpha: 0.48)
    )
    static let loginToastBackground = loginDynamic(
        light: UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 0.92),
        dark: UIColor(red: 0.16, green: 0.18, blue: 0.21, alpha: 0.96)
    )

    private static func loginDynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

private struct SettingsProfileCard: View {
    var snapshot: NinebotVehicleSnapshot?
    var accountText: String
    var vehicleCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ProfileAvatar(urlString: avatarURLString, displayName: displayName)

            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(vehicleCount)")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                .accessibilityLabel("车辆 \(vehicleCount) 台")
        }
        .padding(.vertical, 6)
    }

    private var displayName: String {
        let accountName = snapshot?.vehicle.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !accountName.isEmpty, !isPlaceholderAccountName(accountName) {
            return accountName
        }

        let phone = snapshot?.vehicle.accountPhone?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? firstRawString(["account_phone", "accountPhone", "phone", "mobile"])
            ?? ""
        if !phone.isEmpty {
            return phone
        }

        let resolved = snapshot?.vehicle.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !resolved.isEmpty, !isPlaceholderAccountName(resolved) {
            return resolved
        }

        return firstRawString([
            "account_name",
            "accountName",
            "owner_user_nickname",
            "ownerUserNickname",
            "auth_nickname",
            "authNickname",
            "nickname",
            "user_name",
            "userName"
        ]) ?? cleanAccountText
    }

    private var subtitle: String {
        let vehicleName = snapshot?.vehicle.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !vehicleName.isEmpty {
            return vehicleName
        }
        return "NinePlus"
    }

    private var avatarURLString: String? {
        let accountAvatar = snapshot?.vehicle.accountAvatarURLString?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !accountAvatar.isEmpty {
            return accountAvatar
        }

        let resolved = snapshot?.vehicle.ownerAvatarURLString?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !resolved.isEmpty {
            return resolved
        }
        return firstRawString([
            "account_avatar_url",
            "accountAvatarURL",
            "account_avatar",
            "accountAvatar",
            "owner_user_avatar",
            "ownerUserAvatar",
            "auth_avatar",
            "authAvatar",
            "avatar",
            "avatar_url",
            "avatarUrl"
        ])
    }

    private var cleanAccountText: String {
        let value = accountText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "NineBot+" : value
    }

    private func isPlaceholderAccountName(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("cv_") || normalized.hasPrefix("nv_")
    }

    private func firstRawString(_ keys: [String]) -> String? {
        guard let raw = snapshot?.vehicle.raw else { return nil }
        for key in keys {
            if let value = raw[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }
}

private struct ProfileAvatar: View {
    var urlString: String?
    var displayName: String
    @State private var loadedImage: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.tertiarySystemGroupedBackground))

            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
        }
        .task(id: urlString) {
            loadedImage = await Self.loadAvatar(urlString)
        }
    }

    private var fallback: some View {
        Text(initialText)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var initialText: String {
        let value = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = value.first else { return "N" }
        return String(first)
    }

    @MainActor
    private static func loadAvatar(_ value: String?) async -> UIImage? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }

        var request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 15
        )
        request.setValue("NineBotPlus/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  !data.isEmpty,
                  data.count <= 2_500_000 else {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

private struct SettingsInputField: View {
    var title: String
    var placeholder: String
    var systemImage: String
    @Binding var text: String
    var isSecure = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
            }
        }
    }
}

private struct PushDeviceTokenRow: View {
    var token: String?
    var hasConfiguration: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: token == nil ? "bell.slash.fill" : "bell.badge.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(token == nil ? Color.orange : Color.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(token == nil ? "APNs 设备未上报" : "APNs 设备已就绪")
                    .font(.subheadline.weight(.semibold))
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
    }

    private var detailText: String {
        guard let token, !token.isEmpty else {
            return hasConfiguration ? "点“检查权限并上报”，会重新注册 APNs 并同步到服务器后台。" : "先保存 NinePlus 服务器地址和 Token。"
        }
        let prefix = token.prefix(8)
        let suffix = token.suffix(6)
        return "Token \(prefix)...\(suffix)"
    }
}

private struct SettingsNavigationRow: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color = .green

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct NinebotDiagnosticsView: View {
    @ObservedObject var model: NinebotViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var copiedMessage: String?
    @State private var isRefreshingCaches = false
    @State private var pendingDestructiveAction: DiagnosticsDestructiveAction?
    @AppStorage(NinebotAppearanceMode.storageKey)
    private var appearanceModeRaw = NinebotAppearanceMode.system.rawValue

    private var diagnostics: NinebotDiagnosticsSnapshot {
        model.diagnosticsSnapshot()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DiagnosticsHeroCard(diagnostics: diagnostics)

                DiagnosticsAppearanceCard(
                    selectedModeRawValue: $appearanceModeRaw
                )

                Toggle(isOn: capturePrivacyProtectionBinding) {
                    SettingsNavigationRow(
                        title: "截图录屏保护",
                        subtitle: "隐藏首页地址、车辆位置地图和地址",
                        systemImage: "eye.slash.fill",
                        tint: .blue
                    )
                }
                .tint(.blue)
                .padding(16)
                .ninePlusCard(cornerRadius: 24)

                DiagnosticsEventCard(title: "App / 快捷指令", event: diagnostics.lastAppRefreshEvent)
                DiagnosticsEventCard(title: "桌面小组件", event: diagnostics.lastWidgetRefreshEvent)

                DiagnosticsCacheCard(diagnostics: diagnostics)

                VStack(alignment: .leading, spacing: 12) {
                    Text("维护")
                        .font(.headline)
                        .foregroundStyle(Color.teslaPrimaryText)

                    Button {
                        refreshCaches()
                    } label: {
                        DiagnosticsActionRow(
                            title: "刷新缓存",
                            subtitle: "清除车况、曲线、地址和接口行程缓存后重新拉取",
                            systemImage: "arrow.clockwise.circle.fill",
                            tint: .blue,
                            isWorking: isRefreshingCaches
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshingCaches || model.isLoading)

                    Divider()

                    Button {
                        pendingDestructiveAction = .logout
                    } label: {
                        DiagnosticsActionRow(
                            title: "退出登录",
                            subtitle: "清除九号账号会话和车况缓存，保留服务器配置、本地记录与偏好",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button {
                        pendingDestructiveAction = .reset
                    } label: {
                        DiagnosticsActionRow(
                            title: "重置全部本地数据",
                            subtitle: "清除登录、服务器配置、缓存、本地轨迹和偏好；不删除服务器数据",
                            systemImage: "trash.fill",
                            tint: .red
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .ninePlusCard(cornerRadius: 24)

                Button(role: .destructive) {
                    model.clearMessages()
                    copiedMessage = "已清除当前提示"
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_300_000_000)
                        copiedMessage = nil
                    }
                } label: {
                    SettingsNavigationRow(
                        title: "清除当前提示",
                        subtitle: "移除页面上的状态或错误提示",
                        systemImage: "xmark.circle",
                        tint: .red
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(16)
                .ninePlusCard(cornerRadius: 24)

                DiagnosticsRawCopyCard(
                    snapshot: model.dashboard.primaryVehicle,
                    copiedMessage: $copiedMessage
                )
            }
            .padding(16)
        }
        .background(Color.teslaPageBackground.ignoresSafeArea())
        .navigationTitle("诊断中心")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let copiedMessage {
                Text(copiedMessage)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: copiedMessage)
        .confirmationDialog(
            pendingDestructiveAction?.title ?? "",
            isPresented: Binding(
                get: { pendingDestructiveAction != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDestructiveAction = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("继续", role: .destructive) {
                guard let action = pendingDestructiveAction else { return }
                pendingDestructiveAction = nil
                perform(action)
            }
            Button("取消", role: .cancel) {
                pendingDestructiveAction = nil
            }
        } message: {
            Text(pendingDestructiveAction?.message ?? "")
        }
    }

    private var capturePrivacyProtectionBinding: Binding<Bool> {
        Binding(
            get: { model.capturePrivacyProtectionEnabled },
            set: { model.setCapturePrivacyProtectionEnabled($0) }
        )
    }

    private func refreshCaches() {
        guard !isRefreshingCaches else { return }
        isRefreshingCaches = true
        Task { @MainActor in
            await model.refreshCaches()
            isRefreshingCaches = false
            copiedMessage = model.errorMessage == nil ? "缓存已刷新" : "缓存已清除，重新拉取失败"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copiedMessage = nil
        }
    }

    private func perform(_ action: DiagnosticsDestructiveAction) {
        switch action {
        case .logout:
            model.logoutCurrentAccount()
        case .reset:
            model.resetAllLocalData()
        }
        dismiss()
    }
}

private enum DiagnosticsDestructiveAction: String, Identifiable {
    case logout
    case reset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logout: return "退出当前九号账号？"
        case .reset: return "重置全部本地数据？"
        }
    }

    var message: String {
        switch self {
        case .logout:
            return "会清除九号登录会话、车况和缓存，保留服务器地址、Token、本地骑行记录和设置。"
        case .reset:
            return "会清除本机全部 NinePlus 数据，包括服务器配置、Token、登录状态、本地轨迹和偏好。服务器数据库不会受影响。"
        }
    }
}

private struct DiagnosticsAppearanceCard: View {
    @Binding var selectedModeRawValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(Color.teslaGreen)
                Text("外观")
                    .font(.headline)
                    .foregroundStyle(Color.teslaPrimaryText)
            }

            Picker("外观", selection: $selectedModeRawValue) {
                ForEach(NinebotAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Text("可手动选择浅色或深色，也可以跟随系统外观自动切换。")
                .font(.caption)
                .foregroundStyle(Color.teslaSecondaryText)
        }
        .padding(16)
        .ninePlusCard(cornerRadius: 24)
    }
}

private struct DiagnosticsActionRow: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    var isWorking = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.teslaPrimaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.teslaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isWorking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.teslaSecondaryText)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct DiagnosticsHeroCard: View {
    var diagnostics: NinebotDiagnosticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill((diagnostics.hasConfiguration ? Color.green : Color.orange).opacity(0.14))
                    Image(systemName: diagnostics.hasConfiguration ? "checkmark.seal.fill" : "link.badge.plus")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(diagnostics.hasConfiguration ? Color.green : Color.orange)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(diagnostics.selectedVehicleName)
                        .font(.headline)
                        .foregroundStyle(Color.teslaPrimaryText)
                        .lineLimit(1)
                    Text(diagnostics.serverText)
                        .font(.caption)
                        .foregroundStyle(Color.teslaSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(diagnostics.vehicleCount)")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.teslaPrimaryText)
                    Text("车辆")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.teslaSecondaryText)
                }
            }

            HStack(spacing: 10) {
                DiagnosticMetricPill(title: "账号", value: diagnostics.accountText == "未绑定账号" ? "0" : "1", systemImage: "person.fill")
                DiagnosticMetricPill(title: "地址", value: "\(diagnostics.resolvedAddressCount)", systemImage: "map.fill")
                DiagnosticMetricPill(title: "详情", value: "\(diagnostics.rideDetailCount)", systemImage: "doc.text.magnifyingglass")
            }

            if let updatedAt = diagnostics.dashboardUpdatedAt {
                Label("车况更新 \(formatDiagnosticsDate(updatedAt))", systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.teslaSecondaryText)
            }

            if let lastError = diagnostics.lastError, !lastError.isEmpty {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.teslaCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.teslaHairline, lineWidth: 1)
        }
    }
}

private struct DiagnosticsEventCard: View {
    var title: String
    var event: NinebotRefreshEvent?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.teslaPrimaryText)
                Spacer()
                Text(event?.success == true ? "成功" : "待检查")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(event?.success == true ? Color.green : Color.orange)
            }

            if let event {
                HStack(spacing: 10) {
                    DiagnosticMetricPill(title: "来源", value: event.source, systemImage: "bolt.horizontal")
                    DiagnosticMetricPill(title: "耗时", value: formatDiagnosticsDuration(event.durationSeconds), systemImage: "timer")
                    DiagnosticMetricPill(title: "时间", value: formatDiagnosticsTime(event.endedAt), systemImage: "clock")
                }

                if let message = event.message, !message.isEmpty {
                    Text("\(event.operation) · \(message)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.teslaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("还没有记录到刷新事件")
                    .font(.subheadline)
                    .foregroundStyle(Color.teslaSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.teslaCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.teslaHairline, lineWidth: 1)
        }
    }
}

private struct DiagnosticsCacheCard: View {
    var diagnostics: NinebotDiagnosticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本地缓存")
                .font(.headline)
                .foregroundStyle(Color.teslaPrimaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                DiagnosticMetricPill(title: "接口行程", value: "\(diagnostics.interfaceRideCount)", systemImage: "road.lanes")
                DiagnosticMetricPill(title: "历史快照", value: "\(diagnostics.historyPointCount)", systemImage: "clock.arrow.circlepath")
                DiagnosticMetricPill(title: "本地轨迹", value: "\(diagnostics.recordedRideCount)", systemImage: "point.3.connected.trianglepath.dotted")
                DiagnosticMetricPill(title: "车况缓存", value: formatDiagnosticsBytes(diagnostics.dashboardCacheBytes), systemImage: "externaldrive.fill")
            }
        }
        .padding(16)
        .background(Color.teslaCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.teslaHairline, lineWidth: 1)
        }
    }
}

private struct DiagnosticsRawCopyCard: View {
    var snapshot: NinebotVehicleSnapshot?
    @Binding var copiedMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("原始字段")
                    .font(.headline)
                    .foregroundStyle(Color.teslaPrimaryText)
                Spacer()
                Text(snapshot == nil ? "无车辆" : "可复制")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snapshot == nil ? Color.orange : Color.green)
            }

            Text("复制当前车辆、状态、电池和行程返回值，方便排查字段。")
                .font(.caption)
                .foregroundStyle(Color.teslaSecondaryText)

            Button {
                copyRawPayload()
            } label: {
                Label("复制全部原始字段", systemImage: "doc.on.doc.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.green)
            .disabled(snapshot == nil)
        }
        .padding(16)
        .background(Color.teslaCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.teslaHairline, lineWidth: 1)
        }
    }

    private func copyRawPayload() {
        guard let snapshot else { return }
        let payload: [String: JSONValue] = [
            "vehicle": .object(snapshot.vehicle.raw ?? [:]),
            "status": .object(snapshot.state.rawStatus ?? [:]),
            "battery": .object(snapshot.state.rawBattery ?? [:]),
            "travel": .object(snapshot.state.rawTravel ?? [:])
        ]
        let text = diagnosticsJSONString(.object(payload))
        UIPasteboard.general.string = text
        copiedMessage = "已复制原始字段"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            copiedMessage = nil
        }
    }
}

private struct DiagnosticMetricPill: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.teslaSecondaryText)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.teslaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.teslaSecondaryText)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teslaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AccountSummaryRow: View {
    var accountText: String
    var loginResult: NinebotLoginResult?
    var hasAccount: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((hasAccount ? Color.green : Color.orange).opacity(0.14))
                Image(systemName: hasAccount ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(hasAccount ? Color.green : Color.orange)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(hasAccount ? "当前九号账号" : "绑定九号账号")
                    .font(.subheadline.weight(.semibold))
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let detailText {
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
        }
    }

    private var summaryText: String {
        if hasAccount {
            return accountText
        }
        return "绑定后自动刷新车辆数据"
    }

    private var detailText: String? {
        let areaCode = loginResult?.areaCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let region = loginResult?.region?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let businessUID = loginResult?.businessUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = [areaCode.isEmpty ? nil : "+\(areaCode)", region.isEmpty ? nil : region, businessUID.isEmpty ? nil : "UID \(businessUID)"]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct SettingsButtonLabel: View {
    var title: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SettingsCompactButtonLabel: View {
    var title: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ShortcutCapabilityRow: View {
    var title: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("已支持")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
    }
}

private struct SettingsStatusBanner: View {
    var errorMessage: String?
    var statusMessage: String?

    var body: some View {
        if let errorMessage {
            SettingsStatusRow(
                message: errorMessage,
                systemImage: "exclamationmark.triangle.fill",
                color: .red
            )
        } else if let statusMessage {
            SettingsStatusRow(
                message: statusMessage,
                systemImage: "checkmark.circle.fill",
                color: .green
            )
        }
    }
}

private struct SettingsStatusRow: View {
    var message: String
    var systemImage: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

private func formatDiagnosticsDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "MM-dd HH:mm"
    return formatter.string(from: date)
}

private func formatDiagnosticsTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private func formatDiagnosticsDuration(_ seconds: Double) -> String {
    if seconds >= 10 {
        return "\(Int(seconds.rounded()))s"
    }
    return String(format: "%.1fs", seconds)
}

private func formatDiagnosticsBytes(_ bytes: Int) -> String {
    guard bytes > 0 else { return "0 B" }
    if bytes >= 1024 * 1024 {
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
    if bytes >= 1024 {
        return String(format: "%.1f KB", Double(bytes) / 1024)
    }
    return "\(bytes) B"
}

private func diagnosticsJSONString(_ value: JSONValue) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(value),
          let text = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return text
}

struct NinebotSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NinebotSettingsView(model: NinebotViewModel())
                .navigationTitle("我的")
        }
    }
}
