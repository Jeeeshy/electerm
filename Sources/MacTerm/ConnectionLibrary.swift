import Foundation

// History refers to the bookmark, never a copy of its credentials or SSH options.
enum RecentConnection: Codable, Hashable {
    case local, bookmark(UUID), address(String)
}

@MainActor final class ConnectionLibrary: ObservableObject {
    static let shared = ConnectionLibrary(preferences: .shared)
    private let preferences: Preferences
    @Published private(set) var bookmarks: [Bookmark]
    @Published private(set) var recent: [RecentConnection]
    init(preferences: Preferences) {
        self.preferences = preferences
        func load<T: Decodable>(_ key: String, _: T.Type) -> T? {
            preferences.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        }
        bookmarks = load("bookmarks", [Bookmark].self) ?? []
        recent = Array((load("recentConnections", [RecentConnection].self) ?? []).prefix(10))
    }
    private func persist<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { preferences.set(data, forKey: key) }
    }
    func save(_ b: Bookmark) {
        if let i = bookmarks.firstIndex(where: { $0.id == b.id }) { bookmarks[i] = b }
        else { bookmarks.append(b) }
        persist(bookmarks, "bookmarks")
    }
    func remove(_ b: Bookmark) {
        bookmarks.removeAll { $0.id == b.id }
        persist(bookmarks, "bookmarks")
        if recent.contains(.bookmark(b.id)) {
            recent.removeAll { $0 == .bookmark(b.id) }; persist(recent, "recentConnections")
        }
    }
    func record(_ item: RecentConnection) {
        guard recent.first != item else { return }
        // A bookmark might have been removed while its authentication was pending.
        if case let .bookmark(id) = item, !bookmarks.contains(where: { $0.id == id }) { return }
        recent = [item] + recent.filter { $0 != item }.prefix(9)
        persist(recent, "recentConnections")
    }
    func clearRecent() {
        recent = []; preferences.set(nil, forKey: "recentConnections")
    }
}
