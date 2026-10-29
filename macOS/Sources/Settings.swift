import ScreenSaver

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

    private static let store: ScreenSaverDefaults = {
        let id = Bundle(for: CodeTilesView.self).bundleIdentifier ?? "com.charlie.CodeTiles"
        let d = ScreenSaverDefaults(forModuleWithName: id)!
        d.register(defaults: [
            Key.density: standard.density,
            Key.labelFraction: standard.labelFraction,
            Key.fadeIn: standard.fadeIn,
            Key.fadeOut: standard.fadeOut,
            Key.extensions: standard.extensions,
            Key.darkMode: standard.darkMode,
        ])
        return d
    }()

    private enum Key {
        static let density = "density"
        static let labelFraction = "labelFraction"
        static let fadeIn = "fadeIn"
        static let fadeOut = "fadeOut"
        static let extensions = "extensions"
        static let darkMode = "darkMode"
    }

    static func load() -> Settings {
        let d = store
        return Settings(
            density: number(d, Key.density, standard.density, densityRange),
            labelFraction: number(d, Key.labelFraction, standard.labelFraction, labelRange),
            fadeIn: number(d, Key.fadeIn, standard.fadeIn, fadeRange),
            fadeOut: number(d, Key.fadeOut, standard.fadeOut, fadeRange),
            extensions: sanitize(d.stringArray(forKey: Key.extensions) ?? standard.extensions),
            darkMode: d.bool(forKey: Key.darkMode)
        )
    }

    // The prefs file is user-editable, so NaN/infinity must not reach the animation timing.
    private static func number(_ d: UserDefaults, _ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
        let value = d.double(forKey: key)
        return value.isFinite ? value.clamped(to: range) : fallback
    }

    func save() {
        let d = Settings.store
        d.set(density, forKey: Key.density)
        d.set(labelFraction, forKey: Key.labelFraction)
        d.set(fadeIn, forKey: Key.fadeIn)
        d.set(fadeOut, forKey: Key.fadeOut)
        d.set(extensions, forKey: Key.extensions)
        d.set(darkMode, forKey: Key.darkMode)
        d.synchronize()
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
