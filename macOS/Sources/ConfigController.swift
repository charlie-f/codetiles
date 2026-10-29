import AppKit

// The System Settings screen saver host refuses to present a sheet whose window
// reports it can't become key, so force it.
private final class ConfigWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ConfigController: NSObject {
    let window: NSWindow

    private var onSave: ((Settings) -> Void)?

    private let density = NSSlider(value: 0, minValue: Settings.densityRange.lowerBound, maxValue: Settings.densityRange.upperBound, target: nil, action: nil)
    private let labelFraction = NSSlider(value: 0, minValue: Settings.labelRange.lowerBound, maxValue: Settings.labelRange.upperBound, target: nil, action: nil)
    private let fadeIn = NSSlider(value: 0, minValue: Settings.fadeRange.lowerBound, maxValue: Settings.fadeRange.upperBound, target: nil, action: nil)
    private let fadeOut = NSSlider(value: 0, minValue: Settings.fadeRange.lowerBound, maxValue: Settings.fadeRange.upperBound, target: nil, action: nil)

    private let densityValue = ConfigController.valueLabel()
    private let labelFractionValue = ConfigController.valueLabel()
    private let fadeInValue = ConfigController.valueLabel()
    private let fadeOutValue = ConfigController.valueLabel()

    private let extensionsField = NSTextField(string: "")
    private let darkMode = NSButton(checkboxWithTitle: "Dark mode (black background)", target: nil, action: nil)

    override init() {
        window = ConfigWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.isReleasedWhenClosed = false
        window.title = "Code Tiles"
        buildUI()
    }

    func show(_ settings: Settings, onSave: @escaping (Settings) -> Void) {
        self.onSave = onSave
        apply(settings)
    }

    // MARK: - UI

    private static func valueLabel() -> NSTextField {
        let f = NSTextField(labelWithString: "")
        f.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        f.alignment = .right
        f.widthAnchor.constraint(equalToConstant: 56).isActive = true
        return f
    }

    private static func rowLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.alignment = .right
        return f
    }

    private func buildUI() {
        for slider in [density, labelFraction, fadeIn, fadeOut] {
            slider.target = self
            slider.action = #selector(sliderChanged)
            slider.isContinuous = true
        }

        extensionsField.placeholderString = ".js .ts .py .rb .go"
        extensionsField.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        extensionsField.lineBreakMode = .byTruncatingTail

        let hint = NSTextField(wrappingLabelWithString: "Separate with spaces or commas. Any text works, e.g. .json .toml if()")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        let empty = NSGridCell.emptyContentView
        let grid = NSGridView(views: [
            [Self.rowLabel("Tile density:"), density, densityValue],
            [Self.rowLabel("Tiles with extensions:"), labelFraction, labelFractionValue],
            [Self.rowLabel("Fade in:"), fadeIn, fadeInValue],
            [Self.rowLabel("Fade out:"), fadeOut, fadeOutValue],
            [Self.rowLabel("Appearance:"), darkMode, empty],
            [Self.rowLabel("Extensions:"), extensionsField, empty],
            [empty, hint, empty],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        for row in 4...6 {
            grid.mergeCells(inHorizontalRange: NSRange(location: 1, length: 2), verticalRange: NSRange(location: row, length: 1))
        }
        grid.row(at: 4).topPadding = 4
        grid.row(at: 5).topPadding = 6
        grid.row(at: 6).topPadding = -6
        density.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true

        let defaults = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        let ok = NSButton(title: "OK", target: self, action: #selector(save))
        ok.keyEquivalent = "\r"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let buttons = NSStackView(views: [defaults, spacer, cancel, ok])
        buttons.orientation = .horizontal
        ok.widthAnchor.constraint(greaterThanOrEqualTo: cancel.widthAnchor).isActive = true

        let stack = NSStackView(views: [grid, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        window.contentView = content
        window.setContentSize(content.fittingSize)
    }

    private func apply(_ s: Settings) {
        density.doubleValue = s.density
        labelFraction.doubleValue = s.labelFraction
        fadeIn.doubleValue = s.fadeIn
        fadeOut.doubleValue = s.fadeOut
        extensionsField.stringValue = s.extensions.joined(separator: " ")
        darkMode.state = s.darkMode ? .on : .off
        refreshValues()
    }

    private func current() -> Settings {
        Settings(
            density: (density.doubleValue * 100).rounded() / 100,
            labelFraction: (labelFraction.doubleValue * 100).rounded() / 100,
            fadeIn: (fadeIn.doubleValue * 20).rounded() / 20,
            fadeOut: (fadeOut.doubleValue * 20).rounded() / 20,
            extensions: Settings.parseExtensions(extensionsField.stringValue),
            darkMode: darkMode.state == .on
        )
    }

    private func refreshValues() {
        let s = current()
        densityValue.stringValue = String(format: "%.0f%%", s.density * 100)
        labelFractionValue.stringValue = String(format: "%.0f%%", s.labelFraction * 100)
        fadeInValue.stringValue = String(format: "%.2f s", s.fadeIn)
        fadeOutValue.stringValue = String(format: "%.2f s", s.fadeOut)
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ sender: NSSlider) {
        refreshValues()
    }

    @objc private func restoreDefaults(_ sender: Any) {
        apply(.standard)
    }

    @objc private func cancel(_ sender: Any) {
        close()
    }

    @objc private func save(_ sender: Any) {
        window.makeFirstResponder(nil)
        let s = current()
        s.save()
        onSave?(s)
        close()
    }

    private func close() {
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.orderOut(nil)
        }
    }
}
