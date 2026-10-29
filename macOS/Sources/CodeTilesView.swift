import ScreenSaver
import os

private let logger = Logger(subsystem: Bundle(for: CodeTilesView.self).bundleIdentifier ?? "CodeTiles", category: "saver")

private struct Tile {
    let cell: Int
    let swatch: CALayer
    let text: CATextLayer?
    let born: CFTimeInterval
    let fadeIn: Double
    let fadeOutAt: CFTimeInterval
    let fadeOut: Double

    var diesAt: CFTimeInterval { fadeOutAt + fadeOut }

    func opacity(at now: CFTimeInterval) -> Float {
        let age = now - born
        if age < fadeIn { return Float(age / fadeIn) }
        if now < fadeOutAt { return 1 }
        return Float(max(0, 1 - (now - fadeOutAt) / fadeOut))
    }
}

private struct Label {
    let dark: NSAttributedString
    let light: NSAttributedString
    let height: CGFloat
}

@objc(CodeTilesView)
final class CodeTilesView: ScreenSaverView {
    private static let rowsOnScreen: CGFloat = 14
    private static let clusterChance = 0.6
    private static let secondsToFill = 1.5

    private var settings = Settings.load()
    private var cols = 0
    private var rows = 0
    private var cellSize: CGFloat = 0
    private var origin = CGPoint.zero
    private var tiles: [Tile] = []
    private var occupied: [Bool] = []
    private var labels: [Label] = []
    private var lastFrame: CFTimeInterval = 0
    private var spawnBudget = 0.0
    private var config: ConfigController?
    private static var pendingExit: DispatchWorkItem?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()

        // Since Sonoma the legacyScreenSaver host keeps stopped instances alive and stacks new ones;
        // quitting on willstop is the standard workaround.
        if !isPreview {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(screenSaverWillStop),
                name: Notification.Name("com.apple.screensaver.willstop"),
                object: nil
            )
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        animationTimeInterval = 1.0 / 60.0
        wantsLayer = true
        layoutGrid()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func screenSaverWillStop(_ note: Notification) {
        logger.notice("Screen saver stopping; host process will exit in 2 s")
        Self.pendingExit?.cancel()
        let work = DispatchWorkItem { exit(0) }
        Self.pendingExit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    override func startAnimation() {
        // The saver can restart within the exit grace period; don't kill the new session.
        Self.pendingExit?.cancel()
        Self.pendingExit = nil
        settings = Settings.load()
        buildLabels()
        needsDisplay = true
        lastFrame = 0
        super.startAnimation()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        if changed { layoutGrid() }
    }

    override var isOpaque: Bool { true }

    override func draw(_ rect: NSRect) {
        Palette.background(dark: settings.darkMode).setFill()
        rect.fill()
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    // MARK: - Grid

    private func layoutGrid() {
        cellSize = max(6, (bounds.height / Self.rowsOnScreen).rounded())
        cols = max(1, Int((bounds.width / cellSize).rounded(.up)))
        rows = max(1, Int((bounds.height / cellSize).rounded(.up)))
        origin = CGPoint(
            x: ((bounds.width - CGFloat(cols) * cellSize) / 2).rounded(),
            y: ((bounds.height - CGFloat(rows) * cellSize) / 2).rounded()
        )
        for tile in tiles { remove(tile) }
        tiles.removeAll()
        occupied = Array(repeating: false, count: cols * rows)
        spawnBudget = 0
        buildLabels()
    }

    private func buildLabels() {
        let baseSize = max(5, cellSize * 0.22)
        let maxWidth = cellSize * 0.84
        let darkText = NSColor(white: 0.08, alpha: 0.88)
        let lightText = NSColor(white: 1, alpha: 0.45)
        labels = settings.extensions.map { text in
            var font = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
            let width = NSAttributedString(string: text, attributes: [.font: font]).size().width
            if width > maxWidth {
                font = .monospacedSystemFont(ofSize: max(3, baseSize * maxWidth / width), weight: .regular)
            }
            let dark = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: darkText])
            let light = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: lightText])
            return Label(dark: dark, light: light, height: dark.size().height)
        }
    }

    private func rect(for cell: Int) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cell % cols) * cellSize,
            y: origin.y + CGFloat(cell / cols) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    private func pickEmptyCell() -> Int? {
        if !tiles.isEmpty, Double.random(in: 0..<1) < Self.clusterChance {
            for _ in 0..<6 {
                let base = tiles.randomElement()!.cell
                let c = base % cols, r = base / cols
                let (nc, nr) = [(c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)].randomElement()!
                guard nc >= 0, nc < cols, nr >= 0, nr < rows else { continue }
                let i = nr * cols + nc
                if !occupied[i] { return i }
            }
        }
        for _ in 0..<24 {
            let i = Int.random(in: 0..<occupied.count)
            if !occupied[i] { return i }
        }
        return occupied.indices.filter { !occupied[$0] }.randomElement()
    }

    private func spawn(at cell: Int, now: CFTimeInterval) {
        guard let root = layer else { return }
        let frame = rect(for: cell)
        let color = Palette.tiles.randomElement()!

        let swatch = CALayer()
        swatch.frame = frame
        swatch.backgroundColor = color.cgColor
        swatch.opacity = 0
        root.addSublayer(swatch)

        var text: CATextLayer?
        if !labels.isEmpty, Double.random(in: 0..<1) < settings.labelFraction {
            let label = labels.randomElement()!
            let t = CATextLayer()
            let s = scale
            t.string = color.isDark ? label.light : label.dark
            t.alignmentMode = .center
            t.truncationMode = .end
            t.isWrapped = false
            t.contentsScale = s
            let y = ((frame.midY - label.height / 2) * s).rounded() / s
            t.frame = CGRect(x: frame.minX, y: y, width: frame.width, height: label.height)
            t.opacity = 0
            root.addSublayer(t)
            text = t
        }

        tiles.append(Tile(
            cell: cell,
            swatch: swatch,
            text: text,
            born: now,
            fadeIn: settings.fadeIn,
            fadeOutAt: now + settings.fadeIn + Self.randomHold(),
            fadeOut: settings.fadeOut
        ))
        occupied[cell] = true
    }

    // Skewed toward short holds: matches the reference video, where tiles stay fully visible
    // ~1.6 s at the median (quartiles ~0.8 s / ~2.6 s).
    private static func randomHold() -> Double {
        0.4 + 3.4 * pow(Double.random(in: 0..<1), 1.5)
    }

    private func remove(_ tile: Tile) {
        tile.swatch.removeFromSuperlayer()
        tile.text?.removeFromSuperlayer()
    }

    // MARK: - Animation

    override func animateOneFrame() {
        let now = CACurrentMediaTime()
        let dt = lastFrame == 0 ? animationTimeInterval : min(0.25, now - lastFrame)
        lastFrame = now

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        tiles.removeAll { tile in
            guard now >= tile.diesAt else { return false }
            remove(tile)
            occupied[tile.cell] = false
            return true
        }

        let target = Int((settings.density * Double(cols * rows)).rounded())
        let live = tiles.reduce(0) { $0 + (now < $1.fadeOutAt ? 1 : 0) }
        var deficit = target - live

        // A spawn budget staggers births so tiles never appear in lockstep.
        spawnBudget = min(spawnBudget + Double(target) * dt / Self.secondsToFill, 5)
        while deficit > 0, spawnBudget >= 1, let cell = pickEmptyCell() {
            spawn(at: cell, now: now)
            deficit -= 1
            spawnBudget -= 1
        }

        for tile in tiles {
            let alpha = tile.opacity(at: now)
            tile.swatch.opacity = alpha
            // Labels outlast their tile colour slightly, leaving the faint "ghost" text seen in the video.
            tile.text?.opacity = alpha.squareRoot()
        }

        CATransaction.commit()
    }

    // MARK: - Configuration

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        logger.notice("Options sheet requested (preview: \(self.isPreview, privacy: .public))")
        // The System Settings host tears down the window it presented, so a reused
        // window can't be shown again; build a fresh one every time.
        let controller = ConfigController()
        controller.show(Settings.load()) { [weak self] saved in
            self?.settings = saved
            self?.buildLabels()
            self?.needsDisplay = true
        }
        config = controller
        return controller.window
    }
}
