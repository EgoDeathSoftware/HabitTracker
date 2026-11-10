import CoreData
import Foundation

/// The context is private; callers can only use it on its own queue through transaction().
/// https://developer.apple.com/documentation/coredata/using-core-data-in-the-background
final class PersistenceController: @unchecked Sendable {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    private init(container: NSPersistentContainer) {
        self.container = container
        context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .errorMergePolicyType)
        context.undoManager = nil
    }

    static func open(storeURL: URL, modelVersion: String? = nil) async throws -> PersistenceController {
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            guard let directory = Bundle.main.url(forResource: "HabitTracker", withExtension: "momd")
            else { throw HabitError.storeUnavailable }
            let modelURL = modelVersion.map { directory.appendingPathComponent("\($0).mom") }
                ?? directory
            guard
                  let model = NSManagedObjectModel(contentsOf: modelURL) else {
                throw HabitError.storeUnavailable
            }
            let container = NSPersistentContainer(name: "HabitTracker", managedObjectModel: model)
            let description = NSPersistentStoreDescription(url: storeURL)
            description.type = NSSQLiteStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.setOption(
                FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
            container.persistentStoreDescriptions = [description]
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                container.loadPersistentStores { _, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            return PersistenceController(container: container)
        } catch {
            // Never reset, delete, or substitute an empty store after an open/migration failure.
            throw HabitError.storeUnavailable
        }
    }

    func transaction<T: Sendable>(
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await context.perform {
            do {
                let value = try operation(self.context)
                if self.context.hasChanges { try self.context.save() }
                return value
            } catch {
                self.context.rollback()
                if let error = error as? HabitError { throw error }
                throw HabitError.saveFailed
            }
        }
    }
}
