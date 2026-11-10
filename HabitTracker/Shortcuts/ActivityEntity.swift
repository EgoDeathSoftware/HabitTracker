import AppIntents
import Foundation

struct ActivityEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static let defaultQuery = ActivityEntityQuery()

    let id: UUID
    let name: String
    let symbolName: String

    init(_ activity: ActivitySnapshot) {
        id = activity.id
        name = activity.name
        symbolName = activity.symbolName
    }

    static func code(for id: UUID) -> String { String(id.uuidString.prefix(8)) }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)", subtitle: "Code \(Self.code(for: id))",
            image: .init(systemName: symbolName)
        )
    }
}

struct ActivityEntityQuery: EntityStringQuery {
    private let store: HabitStore?

    init() { store = nil }
    init(store: HabitStore) { self.store = store }

    func entities(for identifiers: [UUID]) async throws -> [ActivityEntity] {
        let byID = try await Dictionary(uniqueKeysWithValues: activities().map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0] }
    }

    func entities(matching string: String) async throws -> [ActivityEntity] {
        try await activities().filter {
            $0.name.localizedCaseInsensitiveContains(string)
                || ActivityEntity.code(for: $0.id).localizedCaseInsensitiveContains(string)
        }
    }

    func suggestedEntities() async throws -> [ActivityEntity] { try await activities() }

    private func activities() async throws -> [ActivityEntity] {
        let snapshots: [ActivitySnapshot]
        if let store {
            let now = try ClockReading(instant: Date(), timeZone: .current)
            snapshots = try await store.snapshot(at: now).timeline.activities
        } else {
            snapshots = try await AppEnvironment.shared.shortcutActivities()
        }
        return snapshots.map(ActivityEntity.init).sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }
}
