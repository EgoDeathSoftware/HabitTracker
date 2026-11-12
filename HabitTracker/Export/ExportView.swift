import SwiftUI
import UIKit

struct ExportView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var start = Date()
    @State private var end = Date()
    @State private var exporting = false
    @State private var message: String?
    @State private var task: Task<Void, Never>?
    @State private var sharedFile: ExportFile?
    @State private var temporaryFile: URL?

    var body: some View {
        Form {
            DatePicker("Start date", selection: $start, in: ...Date(), displayedComponents: .date)
            DatePicker("End date", selection: $end, in: ...Date(), displayedComponents: .date)
            if let message { Text(message).accessibilityIdentifier("Export status") }
            if exporting {
                ProgressView("Preparing CSV")
                Button("Cancel export") { task?.cancel() }
            } else {
                Button("Export CSV") { export() }
            }
        }
        .navigationTitle("Export history")
        .sheet(item: $sharedFile, onDismiss: releaseFile) { file in
            CSVShareSheet(url: file.url) { sharedFile = nil }
        }
        .onDisappear { task?.cancel() }
    }

    private func export() {
        exporting = true
        message = nil
        task = Task { @MainActor in
            defer { exporting = false }
            do {
                let now = try ClockReading(instant: Date(), timeZone: .current)
                guard let store = environment.store else { throw HabitError.storeUnavailable }
                let snapshot = try await store.snapshot(at: now)
                let first = try ClockReading(instant: start, timeZone: .current).localDay
                let last = try ClockReading(instant: end, timeZone: .current).localDay
                let url = try await CSVExporter.export(snapshot: snapshot,
                    range: DayRange(start: first, end: last), at: now, directory: CSVExporter.temporaryDirectory)
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                temporaryFile = url
                sharedFile = ExportFile(url: url)
            } catch is CancellationError {
                message = "Export cancelled."
            } catch { message = error.localizedDescription }
        }
    }

    private func releaseFile() {
        if let temporaryFile { try? FileManager.default.removeItem(at: temporaryFile) }
        temporaryFile = nil
    }
}

private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct CSVShareSheet: UIViewControllerRepresentable {
    let url: URL
    let completion: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in completion() }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
