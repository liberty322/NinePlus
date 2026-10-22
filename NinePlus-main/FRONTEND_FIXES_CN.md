# NineBot+ 修复说明

本版本配合当前 NinePlus 后台使用，包含以下修改：

- App 和 Widget 优先请求新的轻量接口 `GET /dashboard`，直接读取服务端缓存。
- 服务端每 60 秒刷新一次车辆状态缓存，因此 App 打开时会先拿到较新的数据。
- Widget 的请求超时从 8 秒调整为 15 秒，并将充电、开锁和普通状态下的刷新间隔分别调整为约 2、5、10 分钟。
- App 后台任务退出后仍会向 iOS 请求刷新，系统实际执行时间由 iOS 决定。
- 后端新增 `owner_name` 和 `owner_avatar_url`，App“我的”页面会优先使用这两个字段加载头像。
- 头像图片改为使用显式 `URLSession` 请求并启用缓存。

## 构建前必须检查

Widget 显示“暂无车辆”最常见的原因是 App 和 Widget 没有共享同一个 App Group。请在 Xcode 中分别检查 `mini-ninebot` 和 `NinebotWidgets` 两个 Target：

1. Signing & Capabilities 中选择同一个开发团队。
2. 两个 Target 都添加 App Groups 能力。
3. 两个 Target 必须勾选完全相同的 App Group。
4. Bundle ID 可保留你自己的配置，但 Widget Bundle ID 建议以 App Bundle ID 为前缀。

构建安装后：

1. 打开 App 并完成一次车辆刷新。
2. 删除旧 Widget，再重新添加。
3. 等待 WidgetKit 完成第一次时间线刷新。

## 刷新能力说明

后台服务可以持续更新缓存，但 iOS 不允许普通 App 在后台可靠地每分钟执行任务。Widget 和后台任务的刷新时间由 iOS 调度，可能被系统延后。本版本能显著提高自动刷新成功率，但无法绕过 iOS 的节流机制。需要秒级通知时，应配置 APNs 推送并由服务端触发通知或 Live Activity 更新。
