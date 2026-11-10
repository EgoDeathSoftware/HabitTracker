import SwiftUI

struct ActivityEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let activity: ActivitySnapshot?
    @State private var name: String
    @State private var symbol: String
    @State private var cadence: Cadence
    @State private var target: Int
    @State private var saving = false
    @State private var error: String?
    private let id: UUID
    private let symbols = ["book", "figure.walk", "drop", "leaf", "dumbbell", "heart", "pencil", "sun.max"]

    init(activity: ActivitySnapshot? = nil) {
        self.activity = activity
        id = activity?.id ?? UUID()
        _name = State(initialValue: activity?.name ?? "")
        _symbol = State(initialValue: activity?.symbolName ?? "book")
        _cadence = State(initialValue: activity?.cadence ?? .daily)
        _target = State(initialValue: activity?.effectiveTarget ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Activity name", text: $name)
                Picker("Icon", selection: $symbol) {
                    ForEach(symbols, id: \.self) { Label($0, systemImage: $0).tag($0) }
                }
                if activity == nil {
                    Picker("Frequency", selection: $cadence) {
                        Text("Every day").tag(Cadence.daily)
                        Text("Days per week").tag(Cadence.weekly)
                    }
                    .onChange(of: cadence) { _, value in target = min(target, value == .daily ? 10 : 7) }
                    Stepper("Target: \(target)", value: $target, in: 1...(cadence == .daily ? 10 : 7))
                    Text(cadence == .daily ? "Completions required each day."
                         : "Distinct days each week. Choose any days; repeated logs on one date earn one day.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(activity == nil ? "New activity" : "Edit activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save activity") { Task { await save() } }.disabled(saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let draft = try HabitDraft(name: name, symbolName: symbol, cadence: cadence, target: target)
            let command: HabitCommand = activity == nil ? .create(id, draft)
                : .rename(id, name: draft.name, symbolName: draft.symbolName)
            if await environment.apply(command) { dismiss() }
            else { error = environment.errorMessage }
        } catch { self.error = error.localizedDescription }
    }
}
