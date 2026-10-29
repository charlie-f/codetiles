import AppKit

struct TileColor {
    let cgColor: CGColor
    let isDark: Bool
}

// Sampled from the reference photos and video frames.
enum Palette {
    static func background(dark: Bool) -> NSColor {
        dark ? .black : color(0xF3F2EE)
    }

    static let tiles: [TileColor] = [
        // greens
        0x4F9A2B, 0x6CC04A, 0x8FD16F, 0x3F6E25, 0x2F5A1E, 0x8C8A22,
        // ochres and oranges
        0xA8962C, 0xC99A3A, 0xD4732A, 0xC2561F, 0xA8552A, 0xB4713F, 0xE08A2C,
        // blues
        0x2D6FE8, 0x1F5FD0, 0x2C2CE0, 0x4A3FD8, 0x283A8C, 0x1E2547,
        // violets
        0x7B4FE0, 0x9B5BDB, 0x7E6FE6, 0xB07BE0,
        // pinks and reds
        0xD2449A, 0xD6406A, 0xC8304A, 0xE35A5A,
        // neutrals
        0x9A9A9E, 0x6E6E78, 0x2A2A30, 0xCFCDC8, 0xE4E2DD, 0xD9C9A8,
    ].map { hex in
        let c = color(hex)
        return TileColor(cgColor: c.cgColor, isDark: luminance(c) < 0.22)
    }

    static func color(_ hex: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func luminance(_ c: NSColor) -> CGFloat {
        0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
    }
}
