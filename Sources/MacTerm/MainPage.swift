import SwiftUI

// Use the back-deployed property wrapper, including on standalone toolchains without SwiftUIMacros.
typealias ViewState<Value> = SwiftUI.State<Value>

private extension Color { init(hex: Int) { self.init(nsColor: NSColor(rgb: hex)) } }
private enum Panel: String, Identifiable { case bookmark, settings; var id: String { rawValue } }

struct MainPage: View {
    @ObservedObject var work: Workspace
    var body: some View {
        if let session = work.current {
            GeometryReader { geometry in
                SessionPage(work: work, session: session, windowWidth: geometry.size.width)
            }
        }
    }
}

private struct SessionPage: View {
    @ObservedObject private var preferences = Preferences.shared
    @ObservedObject var work: Workspace
    @ObservedObject var session: Session
    let windowWidth: CGFloat
    @ViewState private var choosingPanes = false
    @AppSetting("interfaceTheme") private var theme = InterfaceTheme.system
    @StateObject private var system = SystemAppearance()
    private var scheme: ColorScheme { theme.scheme ?? (system.light ? .light : .dark) }
    private var light: Bool { scheme == .light }
    private var themePicker: some View {
        Picker("界面主题", selection: $theme) {
            ForEach(InterfaceTheme.allCases, id: \.self) { Text($0.title).tag($0) }
        }
    }
    @AppSetting("sidebarWidth") private var sidebarWidth = 224.0
    @AppSetting("fontSize") private var fontSize = 13.0
    @AppSetting("keepalive") private var keepalive = true
    @AppSetting("shellTracking") private var shellTracking = true
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
    @ViewState private var quick = ""
    @ViewState private var quickPopover = false
    @FocusState private var quickFocused: Bool
    @ViewState private var editing: Bookmark?
    @ViewState private var panel: Panel?
    @ViewState private var search = false
    @ViewState private var searchText = ""
    @ViewState private var dragWidth: Double?
    private var chromeRGB: Int { light ? 0xe3e7eb : 0x151515 }
    private var chrome: Color { Color(hex: chromeRGB) }
    private var bodyColor: Color { Color(hex: light ? 0xf6f7f8 : 0x222222) }
    private var edge: Color { Color(hex: light ? 0xc6ccd0 : 0x484848) }

    var body: some View {
        page(session)
        .background(chrome.ignoresSafeArea(.container, edges: .top))
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarColorScheme(scheme, for: .windowToolbar)
        .font(.system(size: 12)).buttonStyle(.plain)
        .background(WindowTitleTint(rgb: chromeRGB).frame(width: 0, height: 0))
        .onChange(of: cursor) { work.sessions.forEach { $0.screen.setCursor(cursor) } }
        .onChange(of: fontFamily) { updateFonts() }
        .onChange(of: fontSize) { updateFonts() }
        .onChange(of: light, initial: true) { work.sessions.forEach { $0.screen.setTheme(light: light) } }
        .onChange(of: scrollback) { work.sessions.forEach { $0.screen.view.changeScrollback(scrollback) } }
        .onChange(of: defaultWrap) { for tab in work.sessions { tab.wrap = defaultWrap; tab.screen.setWrap(defaultWrap) } }
        .onChange(of: defaultFollow) { for tab in work.sessions where tab.endpoint != nil { tab.setFollow(defaultFollow) } }
        .onChange(of: defaultMonitor) { for tab in work.sessions where tab.endpoint != nil { tab.monitor = defaultMonitor } }
        .sheet(item: $panel) { item in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(item == .bookmark ? (editing == nil ? "新建书签" : "编辑书签") : "设置").font(.headline)
                    Spacer(); icon("xmark", "关闭") { panel = nil }.keyboardShortcut(.cancelAction)
                }
                if item == .bookmark {
                    BookmarkEditor(original: editing) { saved in
                        if let i = work.bookmarks.firstIndex(where: { $0.id == saved.id }) { work.bookmarks[i] = saved }
                        else { work.bookmarks.append(saved) }
                        panel = nil
                    }
                } else {
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
                            themePicker
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
                            Picker("采样间隔", selection: $monitorInterval) {
                                ForEach([2, 3, 5, 10], id: \.self) { Text("\($0) 秒").tag($0) }
                            }
                        }
                    }.formStyle(.grouped).frame(height: 400)
                }
            }.padding(18).frame(width: 460)
        }
        .preferredColorScheme(scheme)
    }
    private func updateFonts() {
        let font = Screen.font(fontSize, family: fontFamily)
        for tab in work.sessions where tab.screen.view.font != font { tab.screen.view.font = font }
    }
    private func page(_ s: Session) -> some View {
        let width = work.sidebar == .hidden ? 28.0 : max(150, min(dragWidth ?? sidebarWidth, windowWidth - 250))
        let follow = s.follow
        return VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    tool("bookmark", "新建书签") { editing = nil; panel = .bookmark }
                    tool("terminal", "本地") { work.add() }
                    if s.endpoint != nil {
                        tool("link", "SFTP 跟随终端目录", active: follow) { s.setFollow(!follow) }
                        tool("waveform.path.ecg", "保活", active: keepalive) {
                            keepalive.toggle()
                            s.message = keepalive ? "SSH 保活将在下次连接时开启" : "SSH 保活将在下次连接时关闭"
                        }
                    }
                    tool("antenna.radiowaves.left.and.right", "广播输入", active: work.sendToAll) {
                        work.sendToAll.toggle()
                    }
                    tool("return", "换行", active: s.wrap) {
                        s.wrap.toggle(); s.screen.setWrap(s.wrap)
                    }
                    tool("arrow.up.left.and.arrow.down.right", "全屏") { NSApp.keyWindow?.toggleFullScreen(nil) }
                    tool("magnifyingglass", "搜索", active: search) { search.toggle() }
                    Spacer(minLength: 10)
                    tool("square.split.2x1", "分屏", active: !work.splitIDs.isEmpty) { choosingPanes = true }
                        .popover(isPresented: $choosingPanes) {
                            SplitChooser(work: work) { choosingPanes = false }
                        }
                    if !work.splitIDs.isEmpty {
                        tool("rectangle", "取消分屏") { work.cancelSplit() }
                    }
                    tool("slider.horizontal.3", "设置") { panel = .settings }
                    Menu { themePicker.pickerStyle(.inline).labelsHidden() } label: {
                        toolLabel("circle.lefthalf.filled", "界面主题")
                    }.menuStyle(.borderlessButton).fixedSize().help("界面主题：" + theme.title)
                }.padding(.horizontal, 10).frame(minWidth: windowWidth, alignment: .leading).frame(height: 36)
            }.scrollIndicators(.hidden).frame(height: 36).background(chrome)
            edge.frame(height: 1)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Group {
                        if work.sidebar == .hidden {
                            Button { quickPopover.toggle() } label: {
                                Image(systemName: "bolt.horizontal.circle")
                                    .frame(width: 28, height: 28).contentShape(Rectangle())
                            }.help("快速连接").accessibilityLabel("快速连接")
                                .popover(isPresented: $quickPopover, arrowEdge: .trailing) {
                                    quickEntry(s).padding(8).frame(width: 240)
                                        .onAppear { quickFocused = true }
                                }
                        } else { quickEntry(s) }
                    }.frame(height: 28).background(chrome)
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            railButton("bookmark", "书签夹", selected: work.sidebar == .bookmarks) { work.toggleSidebar(.bookmarks) }
                            railButton("folder", "远程文件", selected: work.sidebar == .files) { work.toggleSidebar(.files) }
                            Spacer()
                        }.frame(width: 28).background(chrome).zIndex(1)
                        if work.sidebar != .hidden {
                            Group {
                                if work.sidebar == .bookmarks { BookmarkList(work: work) { editing = $0; panel = .bookmark } }
                                else if s.endpoint != nil { FilePane(session: s).id(s.id) }
                                else { Text("本地终端没有 SFTP").foregroundStyle(.secondary).padding(8) }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped().contentShape(Rectangle())
                        }
                    }.frame(maxHeight: .infinity, alignment: .top)
                }.frame(width: width).frame(maxHeight: .infinity, alignment: .top).background(bodyColor)
                if work.sidebar != .hidden {
                    SidebarGrip(width: width, limit: windowWidth - 250) { value, finished in
                        if finished { sidebarWidth = value; dragWidth = nil } else { dragWidth = value }
                    }
                    .frame(width: 9).background(edge.frame(width: 1))
                    .help("左右拖动调整侧栏宽度")
                }
                VStack(spacing: 0) {
                    if search {
                        HStack {
                            TextField("搜索终端历史", text: $searchText).onSubmit {
                                s.message = s.screen.find(searchText) ? "" : "无匹配"
                            }
                            icon("xmark", "关闭搜索") { search = false }
                        }.padding(.horizontal, 6).frame(height: 26)
                    }
                    TerminalPanes(work: work, chrome: chrome)
                }
            }
            StatusLine(session: s).id(s.id).frame(height: 24).background(bodyColor)
        }
    }
    private func quickEntry(_ s: Session) -> some View {
        HStack(spacing: 4) {
            TextField("快速连接", text: $quick).focused($quickFocused).onSubmit { connect(s) }.textFieldStyle(.plain)
            icon("arrow.right", "SSH 连接") { connect(s) }.disabled(quick.isEmpty)
        }.padding(.horizontal, 7)
    }
    private func connect(_ s: Session) {
        guard !quick.isEmpty else { return }
        if work.add(quick) != nil { quickPopover = false }
        else { s.message = "无效的 SSH 地址，请使用 user@host:port" }
    }
}

// Tint the native title bar without moving the content or replacing the window controls.
private struct WindowTitleTint: NSViewRepresentable {
    let rgb: Int
    final class Anchor: NSView {
        var rgb: Int?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); applyTint() }
        func applyTint() {
            guard let window, let rgb else { return }
            window.setFrameAutosaveName("")
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.backgroundColor = NSColor(rgb: rgb)
        }
    }
    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) {
        guard view.rgb != rgb else { return }
        view.rgb = rgb; view.applyTint()
    }
}

private func railButton(_ image: String, _ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: selected ? image + ".fill" : image)
            .symbolRenderingMode(.monochrome).foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(selected ? Color.primary.opacity(0.12) : .clear)
            .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(title).help(title)
}

func icon(_ image: String, _ title: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) { Image(systemName: image).frame(minWidth: 17, minHeight: 18) }
        .accessibilityLabel(title).help(title)
}

private func toolLabel(_ image: String, _ title: String, selected: Bool = false) -> some View {
    HStack(spacing: 5) {
        Image(systemName: image).symbolRenderingMode(.monochrome)
            .font(.system(size: 13, weight: .medium)).frame(width: 16)
        Text(title).lineLimit(1)
    }.foregroundStyle(.primary).fixedSize().padding(.horizontal, 6).frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(selected ? 0.12 : 0)))
        .contentShape(Rectangle())
}

private func tool(_ image: String, _ title: String, active: Bool? = nil, _ action: @escaping () -> Void) -> some View {
    Button(action: action) { toolLabel(image, title, selected: active == true) }
        .help(title).accessibilityLabel(title)
        .accessibilityValue(active.map { $0 ? "已开启" : "已关闭" } ?? "")
}

private struct BookmarkList: View {
    @ObservedObject var work: Workspace
    let edit: (Bookmark) -> Void
    @ViewState private var expanded = true
    @ViewState private var selection: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button { expanded.toggle() } label: {
                HStack {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.caption2)
                    Label("SSH 书签夹", systemImage: "folder")
                    Spacer()
                }.frame(height: 28).contentShape(Rectangle())
            }
            if expanded {
                if work.bookmarks.isEmpty { Text("暂无书签").font(.caption).foregroundStyle(.secondary) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(work.bookmarks) { b in
                            Label(b.name, systemImage: "terminal").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 21).background(selection == b.id ? Color.accentColor.opacity(0.28) : .clear)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { work.add(b.address, bookmark: b) }
                                .onTapGesture { selection = b.id }
                                .contextMenu {
                                    Button("编辑书签…") { edit(b) }
                                    Button("删除书签", role: .destructive) {
                                        do {
                                            if b.portablePassword == true { try BookmarkPassword.remove(b.account) }
                                            work.bookmarks.removeAll { $0.id == b.id }
                                        } catch { work.current?.message = error.localizedDescription }
                                    }
                                }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
