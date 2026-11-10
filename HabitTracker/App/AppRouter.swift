import Foundation
import Observation

@MainActor @Observable
final class AppRouter {
    var path: [UUID] = []
    private(set) var navigationID = UUID()
    private(set) var confirmation: MutationReceipt?

    func showActivity(id: UUID, confirmation: MutationReceipt?) {
        self.confirmation = confirmation
        path = [id]
        // Replace nested view-based destinations left open before the shortcut ran.
        navigationID = UUID()
    }

    func clearConfirmation() { confirmation = nil }
}
