import Foundation

struct Settings: Equatable {
    var density: Double
    var labelFraction: Double
    var fadeIn: Double
    var fadeOut: Double
    var extensions: [String]
    var darkMode: Bool

    static let densityRange = 0.05...0.90
    static let labelRange = 0.0...1.0
    static let fadeRange = 0.05...3.0
    static let maxExtensions = 64
    static let maxExtensionLength = 32

    // Fade defaults were measured from the reference video (30 fps): fade-in ~21 frames, fade-out ~24 frames.
    static let standard = Settings(
        density: 0.30,
        labelFraction: 0.35,
        fadeIn: 0.70,
        fadeOut: 0.80,
        extensions: [".js", ".ts", ".py", ".rb", ".go", ".rs", ".c", ".cs", ".kt", ".sh"],
        darkMode: false
    )

    // Same per-host domain ScreenSaverDefaults uses, accessed through CFPreferences so reads
    // can be forced past this process's cache (Options runs in a different process).
    private static let domain = (Bundle(for: CodeTilesView.self).bundleIdentifier ?? "com.charlie.CodeTiles") as CFString

    static let changedNotification = Notification.Name("com.charlie.CodeTiles.settingsChanged")

    private enum Key {
        static let density = "density"
        static let labelFraction = "labelFraction"
        static let fadeIn = "fadeIn"
        static let fadeOut = "fadeOut"
        static let extensions = "extensions"
        static let darkMode = "darkMode"
    }

    static func load() -> Settings {
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        return Settings(
            density: number(Key.density, standard.density, densityRange),
            labelFraction: number(Key.labelFraction, standard.labelFraction, labelRange),
            fadeIn: number(Key.fadeIn, standard.fadeIn, fadeRange),
            fadeOut: number(Key.fadeOut, standard.fadeOut, fadeRange),
            extensions: (value(Key.extensions) as? [String]).map(sanitize) ?? standard.extensions,
            darkMode: (value(Key.darkMode) as? NSNumber)?.boolValue ?? standard.darkMode
        )
    }

    private static func value(_ key: String) -> Any? {
        CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    // The prefs file is user-editable, so NaN/infinity must not reach the animation timing.
    private static func number(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
        guard let number = (value(key) as? NSNumber)?.doubleValue, number.isFinite else { return fallback }
        return number.clamped(to: range)
    }

    func save() {
        let values: [String: Any] = [
            Key.density: density,
            Key.labelFraction: labelFraction,
            Key.fadeIn: fadeIn,
            Key.fadeOut: fadeOut,
            Key.extensions: extensions,
            Key.darkMode: darkMode,
        ]
        for (key, value) in values {
            CFPreferencesSetValue(key as CFString, value as CFPropertyList, Settings.domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        }
        CFPreferencesSynchronize(Settings.domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        // Tell every running instance (the System Settings preview lives in another process).
        DistributedNotificationCenter.default().postNotificationName(
            Settings.changedNotification, object: nil, userInfo: nil, deliverImmediately: true
        )
    }

    static func parseExtensions(_ text: String) -> [String] {
        sanitize(text.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init))
    }

    private static func sanitize(_ list: [String]) -> [String] {
        var seen = Set<String>()
        return Array(
            list
                .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxExtensionLength)) }
                .filter { !$0.isEmpty && seen.insert($0).inserted }
                .prefix(maxExtensions)
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
