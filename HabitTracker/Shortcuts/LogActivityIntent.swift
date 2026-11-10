import AppIntents

struct LogActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Activity"
    static let description = IntentDescription("Record one completion for a saved activity now.")
    // https://developer.apple.com/documentation/appintents/appintent/supportedmodes
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Activity") var activity: ActivityEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        try await AppEnvironment.shared.recordShortcut(activityID: activity.id)
        return .result()
    }
}
