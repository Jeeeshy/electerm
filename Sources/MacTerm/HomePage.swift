import SwiftUI

struct HomePage: View {
    @ObservedObject var work: Workspace
    @ObservedObject var library: ConnectionLibrary
    let showPanel: (Panel) -> Void
    @ViewState private var address = ""
    @ViewState private var error = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("首页").font(.largeTitle.weight(.semibold))
                HStack {
                    TextField("user@host:port 或 SSH 配置别名", text: $address)
                        .textFieldStyle(.roundedBorder).onSubmit(connect)
                    Button("连接", action: connect).disabled(address.isEmpty)
                }
                ViewThatFits(in: .horizontal) {
                    HStack { actions; Spacer(); settingsButton }
                    VStack(alignment: .leading, spacing: 8) { actions; settingsButton }
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                if !work.sessions.isEmpty {
                    Divider()
                    Text("此窗口的标签").font(.headline)
                    ForEach(work.sessions) { s in
                        row(s.title, detail: "返回标签 \(s.number)", icon: "macwindow") { work.choose(s) }
                    }
                }
                Divider()
                HStack {
                    Text("最近连接").font(.headline)
                    Spacer()
                    if !library.recent.isEmpty { Button("清空记录") { library.clearRecent() }.controlSize(.small) }
                }
                if library.recent.isEmpty {
                    Text("暂无最近连接。打开本地终端或连接 SSH 后会显示在这里。")
                        .foregroundStyle(.secondary)
                }
                ForEach(library.recent, id: \.self) { item in
                    switch item {
                    case .local: row("本地终端", detail: "", icon: "terminal") { work.add() }
                    case let .address(value): row(value, detail: "", icon: "network") { work.add(value) }
                    case let .bookmark(id):
                        if let b = library.bookmarks.first(where: { $0.id == id }) {
                            row(b.name, detail: b.name == b.address ? "" : b.address, icon: "bookmark") {
                                work.add(b.address, bookmark: b)
                            }
                        }
                    }
                }
            }.padding(28).frame(maxWidth: 660).frame(maxWidth: .infinity)
        }
    }
    @ViewBuilder private var actions: some View {
        Button { work.add() } label: { Label("新建本地", systemImage: "terminal") }
        Button { showPanel(.bookmark) } label: { Label("连接 SSH…", systemImage: "network") }
        Menu("书签") {
            ForEach(library.bookmarks) { b in
                Button(b.name) { work.add(b.address, bookmark: b) }
            }
        }.fixedSize().disabled(library.bookmarks.isEmpty)
    }
    private var settingsButton: some View {
        Button { showPanel(.settings) } label: { Label("设置", systemImage: "slider.horizontal.3") }
    }
    private func connect() {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || work.add(value) == nil {
            error = "请输入有效的 SSH 地址"
        }
    }
    private func row(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 20)
                Text(verbatim: title).lineLimit(1)
                Spacer()
                Text(verbatim: detail).foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
