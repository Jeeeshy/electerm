import SwiftUI

struct SettingsForm: View {
    @ObservedObject private var preferences = Preferences.shared
    @AppSetting("interfaceTheme") private var theme = InterfaceTheme.system
    @AppSetting("fontSize") private var fontSize = 13.0
    @AppSetting("keepalive") private var keepalive = true
    @AppSetting("shellTracking") private var shellTracking = false
    @AppSetting("scrollback") private var scrollback = 3000
    @AppSetting("defaultWrap") private var defaultWrap = true
    @AppSetting("defaultFollow") private var defaultFollow = true
    @AppSetting("showHiddenFiles") private var showHiddenFiles = false
    @AppSetting("defaultMonitor") private var defaultMonitor = false
    @AppSetting("monitorInterval") private var monitorInterval = 3
    @AppSetting("fontFamily") private var fontFamily = "自动"
    @AppSetting("cursorStyle") private var cursor = "blinkBlock"
    @AppSetting("keepaliveSeconds") private var keepaliveSeconds = 30
    @AppSetting("connectTimeout") private var connectTimeout = 0
    @AppSetting("fileSizeColumn") private var sizes = false
    @AppSetting("fileDateColumn") private var dates = false
    @AppSetting("monitorCPU") private var monitorCPU = true
    @AppSetting("monitorMemory") private var monitorMemory = true
    @AppSetting("monitorDisk") private var monitorDisk = false
    @AppSetting("monitorUsers") private var monitorUsers = false
    @AppSetting("monitorUptime") private var monitorUptime = false
    var body: some View {
        Form {
            Section("终端") {
                Picker("等宽字体", selection: $fontFamily) {
                    ForEach(["自动", "系统等宽", "Menlo", "Monaco"], id: \.self) { Text($0) }
                }
                Picker("光标", selection: $cursor) {
                    Text("闪烁方块").tag("blinkBlock"); Text("方块").tag("steadyBlock")
                    Text("竖线").tag("steadyBar"); Text("下划线").tag("steadyUnderline")
                }
                Stepper("终端字号：\(Int(fontSize))", value: $fontSize, in: 9...28)
                Stepper("历史行数：\(scrollback)", value: $scrollback, in: 500...20000, step: 500)
                Toggle("自动换行", isOn: $defaultWrap)
                Picker("界面主题", selection: $theme) {
                    ForEach(InterfaceTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            Section("SSH 与文件") {
                Toggle("SSH 保活（新连接）", isOn: $keepalive)
                Stepper("保活间隔：\(keepaliveSeconds) 秒（新连接）", value: $keepaliveSeconds, in: 5...300, step: 5).disabled(!keepalive)
                Picker("连接超时（新连接）", selection: $connectTimeout) {
                    Text("遵循 OpenSSH 配置").tag(0)
                    ForEach([5, 10, 30, 60], id: \.self) { Text("\($0) 秒").tag($0) }
                }
                Toggle("文件大小列", isOn: $sizes)
                Toggle("修改日期列", isOn: $dates)
                Toggle("探测远程 shell 目录（新连接）", isOn: $shellTracking)
                Toggle("SFTP 跟随终端", isOn: $defaultFollow)
                Toggle("显示隐藏文件", isOn: $showHiddenFiles)
            }
            Section("远程监控") {
                Toggle("启用远程监控", isOn: $defaultMonitor)
                Toggle("底栏 CPU 占用率", isOn: $monitorCPU)
                Toggle("底栏内存", isOn: $monitorMemory)
                Toggle("底栏硬盘用量", isOn: $monitorDisk)
                Toggle("底栏登录用户", isOn: $monitorUsers)
                Toggle("底栏运行时间", isOn: $monitorUptime)
                Picker("CPU / 内存采样间隔", selection: $monitorInterval) {
                    ForEach([2, 3, 5, 10], id: \.self) { Text("\($0) 秒").tag($0) }
                }
            }
        }.formStyle(.grouped).frame(height: 400)
    }
}
