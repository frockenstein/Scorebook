import Foundation
import Observation

/// Saves each game as a JSON file in Documents/Games and remembers which one is open.
@MainActor
@Observable
final class GameLibrary {
    private(set) var games: [Game] = []
    private let directory: URL
    private let defaults: UserDefaults
    private static let currentKey = "scorebook.currentGame"

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.directory = directory ?? URL.documentsDirectory.appending(path: "Games", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        reload()
    }

    var currentID: UUID? {
        get { defaults.string(forKey: Self.currentKey).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Self.currentKey) }
    }

    var current: Game? { games.first { $0.id == currentID } }

    private func url(for id: UUID) -> URL { directory.appending(path: "\(id.uuidString).json") }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }
    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        games = files.filter { $0.pathExtension == "json" }
            .compactMap { try? Self.decoder.decode(Game.self, from: Data(contentsOf: $0)) }
            .sorted { $0.created > $1.created }
    }

    func save(_ game: Game) {
        if let data = try? Self.encoder.encode(game) { try? data.write(to: url(for: game.id), options: .atomic) }
        if let i = games.firstIndex(where: { $0.id == game.id }) { games[i] = game }
        else { games.insert(game, at: 0); games.sort { $0.created > $1.created } }
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
        games.removeAll { $0.id == id }
        if currentID == id { currentID = games.first?.id }
    }

    func exportURL(for game: Game) -> URL? {
        let name = "\(game.away.name)-at-\(game.home.name)".replacingOccurrences(of: " ", with: "-")
        let out = URL.temporaryDirectory.appending(path: "\(name).scorebook.json")
        guard let data = try? Self.encoder.encode(game) else { return nil }
        try? data.write(to: out, options: .atomic)
        return out
    }

    @discardableResult
    func importGame(from url: URL) -> Game? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              var game = try? Self.decoder.decode(Game.self, from: data),
              (try? GameState(game: game)) != nil else { return nil }
        if games.contains(where: { $0.id == game.id }) { game.id = UUID() }
        save(game)
        return game
    }
}
