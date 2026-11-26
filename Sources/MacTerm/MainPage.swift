import SwiftUI

// Use the back-deployed property wrapper, including on standalone toolchains without SwiftUIMacros.
typealias ViewState<Value> = SwiftUI.State<Value>

private extension Color { init(hex: Int) { self.init(nsColor: NSColor(rgb: hex)) } }
enum Panel: String, Identifiable { case bookmark, settings; var id: String { rawValue } }

struct MainPage: View {
    @ObservedObject var work: Workspace
    @ObservedObject private var preferences = Preferences.shared
    @AppSetting("interfaceTheme") private var theme = InterfaceTheme.system
    @AppSetting("fontSize") private var fontSize = 13.0
    @AppSetting("scrollback") private var scrollback = 3000
    @AppSetting("defaultWrap") private var defaultWrap = true
    @AppSetting("defaultFollow") private var defaultFollow = true
    @AppSetting("defaultMonitor") private var defaultMonitor = false
    @AppSetting("fontFamily") private var fontFamily = "自动"
    @AppSetting("cursorStyle") private var cursor = "blinkBlock"
    @StateObject private var system = SystemAppearance()
    private var scheme: ColorScheme { theme.scheme ?? (system.light ? .light : .dark) }
    private var light: Bool { scheme == .light }
    var body: some View {
        GeometryReader { geometry in
            if let session = work.current {
                SessionPage(work: work, source: session, windowWidth: geometry.size.width, scheme: scheme)
            } else {
                SessionPage(work: work, source: work.library, windowWidth: geometry.size.width, scheme: scheme)
            }
        }
        .background(WindowTitleTint(rgb: light ? 0xe3e7eb : 0x151515).frame(width: 0, height: 0))
        .preferredColorScheme(scheme)
        .onChange(of: cursor) { work.sessions.forEach { $0.screen.setCursor(cursor) } }
        .onChange(of: fontFamily) { updateFonts() }
        .onChange(of: fontSize) { updateFonts() }
        .onChange(of: light, initial: true) { work.sessions.forEach { $0.screen.setTheme(light: light) } }
        .onChange(of: scrollback) { work.sessions.forEach { $0.screen.view.changeScrollback(scrollback) } }
        .onChange(of: defaultWrap) { for tab in work.sessions { tab.wrap = defaultWrap; tab.screen.setWrap(defaultWrap) } }
        .onChange(of: defaultFollow) { for tab in work.sessions where tab.endpoint != nil { tab.setFollow(defaultFollow) } }
        .onChange(of: defaultMonitor) { for tab in work.sessions where tab.endpoint != nil { tab.monitor = defaultMonitor } }
    }
    private func updateFonts() {
        let font = Screen.font(fontSize, family: fontFamily)
        for tab in work.sessions where tab.screen.view.font != font { tab.screen.view.font = font }
    }
}

private struct SessionPage<Source: ObservableObject>: View {
    @ObservedObject private var preferences = Preferences.shared
    @ObservedObject var work: Workspace
    // Observe the active session (or the connection library on the home page).
    @ObservedObject var source: Source
    let windowWidth: CGFloat
    @ViewState private var choosingPanes = false
    @AppSetting("interfaceTheme") private var theme = InterfaceTheme.system
    let scheme: ColorScheme
    private var light: Bool { scheme == .light }
    private var themePicker: some View {
        Picker("界面主题", selection: $theme) {
            ForEach(InterfaceTheme.allCases, id: \.self) { Text($0.title).tag($0) }
        }
    }
    @AppSetting("sidebarWidth") private var sidebarWidth = 224.0
    @AppSetting("keepalive") private var keepalive = true
    @ViewState private var homeMessage = ""
    @ViewState private var quick = ""
    @ViewState private var quickPopover = false
    @FocusState private var quickFocused: Bool
    @ViewState private var editing: Bookmark?
    @ViewState private var panel: Panel?
    @ViewState private var search = false
    @ViewState private var searchText = ""
    @FocusState private var searchFocused: Bool
    @ViewState private var dragWidth: Double?
    private var chromeRGB: Int { light ? 0xe3e7eb : 0x151515 }
    private var chrome: Color { Color(hex: chromeRGB) }
    private var bodyColor: Color { Color(hex: light ? 0xf6f7f8 : 0x222222) }
    private var edge: Color { Color(hex: light ? 0xc6ccd0 : 0x484848) }

    var body: some View {
        page(source as? Session)
        .background(chrome.ignoresSafeArea(.container, edges: .top))
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarColorScheme(scheme, for: .windowToolbar)
        .font(.system(size: 12)).buttonStyle(.plain)
        .sheet(item: $panel) { item in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(item == .bookmark ? (editing == nil ? "连接 SSH" : "编辑书签") : "设置").font(.headline)
                    Spacer(); icon("xmark", "关闭") { panel = nil }.keyboardShortcut(.cancelAction)
                }
                if item == .bookmark {
                    BookmarkEditor(original: editing) { saved, connect in
                        work.library.save(saved)
                        panel = nil
                        if connect { work.add(saved.address, bookmark: saved) }
                    }
                } else {
                    SettingsForm()
                }
            }.padding(18).frame(width: 460)
        }
    }
    private func page(_ s: Session?) -> some View {
        let width = work.sidebar == .hidden ? 28.0 : max(150, min(dragWidth ?? sidebarWidth, windowWidth - 250))
        return VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    tool("network", "连接 SSH") { editing = nil; panel = .bookmark }
                    tool("terminal", "新建本地") { work.add() }
                    if let s, s.endpoint != nil {
                        let follow = s.follow
                        tool("link", "SFTP 跟随终端目录", active: follow) { s.setFollow(!follow) }
                        tool("waveform.path.ecg", "保活", active: keepalive) {
                            keepalive.toggle()
                            s.message = keepalive ? "SSH 保活将在下次连接时开启" : "SSH 保活将在下次连接时关闭"
                        }
                    }
                    tool("antenna.radiowaves.left.and.right", "广播输入", active: work.sendToAll) {
                        work.sendToAll.toggle()
                    }.disabled(s == nil)
                    tool("return", "换行", active: s?.wrap == true) {
                        guard let s else { return }
                        s.wrap.toggle(); s.screen.setWrap(s.wrap)
                    }.disabled(s == nil)
                    tool("arrow.up.left.and.arrow.down.right", "全屏") { NSApp.keyWindow?.toggleFullScreen(nil) }
                    tool("magnifyingglass", "搜索", active: search, hint: "搜索终端历史（⌘F）") {
                        search = true; searchFocused = true
                    }.keyboardShortcut("f", modifiers: .command).disabled(s == nil)
                    Spacer(minLength: 10)
                    tool("square.split.2x1", "分屏", active: !work.splitIDs.isEmpty) { choosingPanes = true }
                        .popover(isPresented: $choosingPanes) {
                            SplitChooser(work: work) { choosingPanes = false }
                        }.disabled(s == nil)
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
                                    quickEntry.padding(8).frame(width: 240)
                                        .onAppear { quickFocused = true }
                                }
                        } else { quickEntry }
                    }.frame(height: 28).background(chrome)
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            railButton("bookmark", "书签夹", selected: work.sidebar == .bookmarks) { work.toggleSidebar(.bookmarks) }
                            railButton("folder", "远程文件", selected: work.sidebar == .files) { work.toggleSidebar(.files) }
                            Spacer()
                        }.frame(width: 28).background(chrome).zIndex(1)
                        if work.sidebar != .hidden {
                            Group {
                                if work.sidebar == .bookmarks {
                                    BookmarkList(work: work, library: work.library, reportError: showMessage) { editing = $0; panel = .bookmark }
                                }
                                else if let s, s.endpoint != nil { FilePane(session: s).id(s.id) }
                                else { Text(s == nil ? "连接 SSH 后可浏览远程文件" : "本地终端没有 SFTP").foregroundStyle(.secondary).padding(8) }
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
                    if search, let s {
                        HStack {
                            TextField("搜索终端历史", text: $searchText)
                                .focused($searchFocused)
                                .onAppear { searchFocused = true }
                                .onSubmit { s.message = s.screen.find(searchText) ? "" : "无匹配" }
                            icon("xmark", "关闭搜索") {
                                search = false
                                s.screen.view.window?.makeFirstResponder(s.screen.view)
                            }
                        }.padding(.horizontal, 6).frame(height: 26)
                    }
                    if s != nil {
                        TerminalPanes(work: work, chrome: chrome)
                    } else {
                        HStack {
                            Label("首页", systemImage: "house")
                            Spacer()
                        }.padding(.horizontal, 10).frame(height: 28).background(chrome)
                        HomePage(work: work, library: work.library) { item in
                            editing = nil; panel = item
                        }.buttonStyle(.automatic)
                        .background(Color(hex: light ? 0xf8f9fa : 0x1e1e1e))
                    }
                }
            }
            Group {
                if let s { StatusLine(session: s).id(s.id) }
                else { Text(homeMessage.isEmpty ? "未连接" : homeMessage).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).frame(maxWidth: .infinity, alignment: .leading) }
            }.frame(height: 24).background(bodyColor)
        }
    }
    private var quickEntry: some View {
        HStack(spacing: 4) {
            TextField("快速连接", text: $quick).focused($quickFocused).onSubmit(connect).textFieldStyle(.plain)
            icon("arrow.right", "SSH 连接") { connect() }.disabled(quick.isEmpty)
        }.padding(.horizontal, 7)
    }
    private func connect() {
        guard !quick.isEmpty else { return }
        if work.add(quick) != nil { quickPopover = false }
        else { showMessage("无效的 SSH 地址，请使用 user@host:port") }
    }
    private func showMessage(_ message: String) {
        if let s = work.current { s.message = message } else { homeMessage = message }
    }
}

// Tint the native title bar without moving the content or replacing the window controls.
struct WindowTitleTint: NSViewRepresentable {
    static let defaultContentSize = NSSize(width: 1120, height: 750)
    let rgb: Int
    final class Anchor: NSView {
        var rgb: Int?
        private var titleClicks: Any?
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if let titleClicks { NSEvent.removeMonitor(titleClicks); self.titleClicks = nil }
            super.viewWillMove(toWindow: newWindow)
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); applyTint()
            guard let window else { return }
            // WindowGroup restores its frame after the content is attached, even when
            // session restoration is disabled. Only correct a screen-filling opening.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let window, self?.window === window else { return }
                Self.restoreNormalSizeIfFilled(window)
            }
            titleClicks = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak window] event in
                guard event.clickCount == 2, let window, event.window === window,
                      !window.styleMask.contains(.fullScreen), window.attachedSheet == nil,
                      event.locationInWindow.y >= window.contentLayoutRect.maxY else { return event }
                let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
                for type in buttons {
                    if let button = window.standardWindowButton(type),
                       button.convert(button.bounds, to: nil).insetBy(dx: -2, dy: -2).contains(event.locationInWindow) { return event }
                }
                let before = window.frame
                window.performZoom(nil)
                if window.frame == before { Self.restoreNormalSizeIfFilled(window) }
                return nil
            }
        }
        private static func restoreNormalSizeIfFilled(_ window: NSWindow) {
            guard !window.styleMask.contains(.fullScreen), let area = window.screen?.visibleFrame,
                  window.frame.width >= area.width - 2, window.frame.height >= area.height - 2 else { return }
            let size = WindowTitleTint.defaultContentSize
            let content = NSRect(x: 0, y: 0, width: min(size.width, area.width * 0.84),
                                 height: min(size.height, area.height * 0.84))
            let frame = window.frameRect(forContentRect: content)
            window.setFrame(NSRect(x: round(area.midX - frame.width / 2), y: round(area.midY - frame.height / 2),
                                   width: frame.width, height: frame.height), display: true)
        }
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

private func tool(_ image: String, _ title: String, active: Bool? = nil, hint: String? = nil, _ action: @escaping () -> Void) -> some View {
    Button(action: action) { toolLabel(image, title, selected: active == true) }
        .help(hint ?? title).accessibilityLabel(title)
        .accessibilityValue(active.map { $0 ? "已开启" : "已关闭" } ?? "")
}

private struct BookmarkList: View {
    @ObservedObject var work: Workspace
    @ObservedObject var library: ConnectionLibrary
    let reportError: (String) -> Void
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
                if library.bookmarks.isEmpty { Text("暂无书签").font(.caption).foregroundStyle(.secondary) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(library.bookmarks) { b in
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
                                            library.remove(b)
                                        } catch { reportError(error.localizedDescription) }
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
