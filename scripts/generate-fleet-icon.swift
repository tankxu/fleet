import AppKit
import CoreGraphics
import CoreText
import Foundation

// Fleet app icon generator.
//
// Regenerates every icon asset from one source artwork:
// `design/fleet-icon-source.png` (an opaque render of the mark on a dark plate).
// Outputs `Assets.xcassets/AppIcon*.appiconset` at every size in light and dark,
// the dock-tile imagesets, and the transparent Icon Composer layer under
// `AppIcon.icon/Assets`.
//
// Usage: swift scripts/generate-fleet-icon.swift .
//
// The artwork is used two ways:
//
// * Dock / app icon: the source render is used whole, masked to a squircle. It is
//   already a finished composition — plate, corner bloom, and mark — so
//   recomposing it would only degrade it.
// * Icon Composer layer and the menu-bar glyph: the mark is lifted off its plate,
//   because macOS 26 draws its own glass plate behind the layer, and a status-item
//   image must be a transparent template.

// MARK: - Palette

enum Palette {
    /// Plate color, sampled from the source artwork's background.
    static let plateTop = CGColor(srgbRed: 0.098, green: 0.110, blue: 0.114, alpha: 1)
    static let plateBottom = CGColor(srgbRed: 0.043, green: 0.051, blue: 0.055, alpha: 1)
    static let plateTopLight = CGColor(srgbRed: 0.153, green: 0.169, blue: 0.176, alpha: 1)
    static let plateBottomLight = CGColor(srgbRed: 0.075, green: 0.086, blue: 0.090, alpha: 1)
    /// The corner bloom the source artwork has behind the mark.
    static let bloom = CGColor(srgbRed: 0.13, green: 0.85, blue: 0.62, alpha: 0.30)
    static let debugBadge = CGColor(srgbRed: 1.0, green: 0.48, blue: 0.0, alpha: 1)
    static let nightlyBadge = CGColor(srgbRed: 0.58, green: 0.31, blue: 0.85, alpha: 1)
}

enum Badge {
    case none, dev, nightly

    var color: CGColor? {
        switch self {
        case .none: nil
        case .dev: Palette.debugBadge
        case .nightly: Palette.nightlyBadge
        }
    }

    var text: String? {
        switch self {
        case .none: nil
        case .dev: "DEV"
        case .nightly: "NIGHTLY"
        }
    }
}

// MARK: - Mark extraction

/// Lifts the mark off the source artwork's dark plate.
///
/// The source is opaque RGB: a bright green mark on near-black, with a cyan-green
/// bloom in one corner. Alpha comes from luminance so the mark keeps its own
/// gradient; the bloom is rejected by hue, since it is bright enough to survive a
/// luminance threshold but far bluer than any part of the mark.
func extractMark(from url: URL) -> CGImage {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("cannot read \(url.path)")
    }
    let width = cgImage.width
    let height = cgImage.height
    var source = [UInt8](repeating: 0, count: width * height * 4)
    guard let readContext = CGContext(
        data: &source,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("no read context") }
    readContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let alphaFloor = 0.10
    let alphaCeiling = 0.30
    var minX = width, minY = height, maxX = 0, maxY = 0
    var output = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0 ..< height {
        for x in 0 ..< width {
            let index = (y * width + x) * 4
            let red = Double(source[index]) / 255
            let green = Double(source[index + 1]) / 255
            let blue = Double(source[index + 2]) / 255
            let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            var alpha = min(max((luma - alphaFloor) / (alphaCeiling - alphaFloor), 0), 1)
            let greenness = green - max(red, blue) * 0.55
            // `blue > green * 0.8` is the bloom test: the mark runs yellow-green
            // through emerald, never cyan.
            if greenness < 0.06 || blue > green * 0.80 { alpha = 0 }
            guard alpha > 0 else { continue }
            // Undo the plate's darkening at the mark's soft edges.
            let scale = 1.0 / max(alpha, 0.35)
            output[index] = UInt8(min(255, red * 255 * scale))
            output[index + 1] = UInt8(min(255, green * 255 * scale))
            output[index + 2] = UInt8(min(255, blue * 255 * scale))
            output[index + 3] = UInt8(alpha * 255)
            if alpha > 0.2 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    guard minX < maxX, minY < maxY else { fatalError("no mark found in source artwork") }

    guard let context = CGContext(
        data: &output,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let extracted = context.makeImage() else { fatalError("no extracted image") }

    // Crop to the mark, then pad to a square so every downstream layout can just
    // center it.
    let cropWidth = maxX - minX + 1
    let cropHeight = maxY - minY + 1
    let side = max(cropWidth, cropHeight)
    guard let squareContext = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("no square context") }
    squareContext.interpolationQuality = .high
    squareContext.draw(
        extracted,
        in: CGRect(
            x: -CGFloat(minX) + CGFloat(side - cropWidth) / 2,
            y: -CGFloat(height - 1 - maxY) + CGFloat(side - cropHeight) / 2,
            width: CGFloat(width),
            height: CGFloat(height)
        )
    )
    guard let squared = squareContext.makeImage() else { fatalError("no squared image") }
    print("mark extracted: \(side)x\(side) from \(width)x\(height)")
    return squared
}

// MARK: - Drawing

/// Apple-style continuous-curvature rounded square, sampled from a superellipse.
/// `CGPath(roundedRect:)` uses circular corners, which read visibly rounder than
/// a system icon at large sizes.
func squirclePath(in rect: CGRect, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    let halfWidth = rect.width / 2
    let halfHeight = rect.height / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    for step in 0 ... steps {
        let theta = 2 * CGFloat.pi * CGFloat(step) / CGFloat(steps)
        let cosine = cos(theta)
        let sine = sin(theta)
        let x = center.x + halfWidth * pow(abs(cosine), 2 / exponent) * (cosine < 0 ? -1 : 1)
        let y = center.y + halfHeight * pow(abs(sine), 2 / exponent) * (sine < 0 ? -1 : 1)
        if step == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    return path
}

/// Dock icon: the source artwork, masked to a squircle.
///
/// Nothing is recomposed — the artwork already carries its own plate and bloom,
/// so the only work here is the platform's shape, inset, shadow, and any variant
/// badge.
func drawDockIcon(artwork: CGImage, mark: CGImage, size: CGFloat, badge: Badge, drawsPlate: Bool) -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("no dock icon context") }
    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let hasBadge = badge != .none
    var plateRect = canvas.insetBy(dx: size * 0.085, dy: size * 0.085)
    if hasBadge {
        plateRect = plateRect.offsetBy(dx: 0, dy: size * 0.03)
    }
    let plate = squirclePath(in: plateRect)

    if drawsPlate {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -size * 0.012),
            blur: size * 0.045,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.40)
        )
        context.addPath(plate)
        context.setFillColor(Palette.plateBottom)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(plate)
        context.clip()
        context.draw(artwork, in: plateRect)
        context.restoreGState()

        // Hairline rim so the plate separates from a dark wallpaper.
        context.saveGState()
        context.addPath(plate)
        context.setLineWidth(max(1, size * 0.0035))
        context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10))
        context.strokePath()
        context.restoreGState()
    } else {
        // Nightly ships without a plate, matching the previous icon set — which
        // means the mark alone on transparency, not the artwork's own dark plate
        // rendered as a bare square.
        let side = plateRect.width * 0.94
        context.draw(mark, in: CGRect(
            x: plateRect.midX - side / 2,
            y: plateRect.midY - side / 2,
            width: side,
            height: side
        ))
    }

    drawBadge(badge, in: context, size: size)
    guard let image = context.makeImage() else { fatalError("no dock icon image") }
    return image
}

/// Variant strip along the bottom edge.
func drawBadge(_ badge: Badge, in context: CGContext, size: CGFloat) {
    guard let badgeColor = badge.color else { return }
    let stripHeight = size * 0.165
    let strip = CGRect(x: 0, y: 0, width: size, height: stripHeight)
    context.saveGState()
    context.addPath(CGPath(
        roundedRect: strip,
        cornerWidth: size * 0.02,
        cornerHeight: size * 0.02,
        transform: nil
    ))
    context.setFillColor(badgeColor)
    context.fillPath()
    context.restoreGState()

    // Below ~64px the label is unreadable and only muddies the strip, so the color
    // alone carries the variant.
    guard size >= 64, let text = badge.text else { return }
    let fontSize = stripHeight * 0.62
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text,
        attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
            .kern: fontSize * 0.02,
        ]
    ))
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    context.saveGState()
    context.textPosition = CGPoint(
        x: (size - bounds.width) / 2 - bounds.minX,
        y: (stripHeight - bounds.height) / 2 - bounds.minY
    )
    CTLineDraw(line, context)
    context.restoreGState()
}

func write(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FleetIcon", code: 1)
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url)
}

// MARK: - Main

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let assets = root.appendingPathComponent("Assets.xcassets")
let sourceURL = root.appendingPathComponent("design/fleet-icon-source.png")

guard let sourceImage = NSImage(contentsOf: sourceURL),
      let artwork = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("cannot read \(sourceURL.path)")
}
let mark = extractMark(from: sourceURL)

struct Variant {
    let directory: String
    let badge: Badge
    let includesDark: Bool
    let drawsPlate: Bool
}

let variants = [
    Variant(directory: "AppIcon.appiconset", badge: .none, includesDark: true, drawsPlate: true),
    Variant(directory: "AppIcon-Debug.appiconset", badge: .dev, includesDark: false, drawsPlate: true),
    Variant(directory: "AppIcon-Nightly.appiconset", badge: .nightly, includesDark: false, drawsPlate: false),
]
let points: [CGFloat] = [16, 32, 128, 256, 512]

for variant in variants {
    let directory = assets.appendingPathComponent(variant.directory)
    for point in points {
        for scale in [1, 2] {
            let pixels = point * CGFloat(scale)
            let suffix = scale == 2 ? "@2x" : ""
            let icon = drawDockIcon(
                artwork: artwork,
                mark: mark,
                size: pixels,
                badge: variant.badge,
                drawsPlate: variant.drawsPlate
            )
            try write(icon, to: directory.appendingPathComponent("\(Int(point))\(suffix).png"))
            // The artwork is already dark; a separate light-appearance rendering
            // would only invent a second brand look, so both slots share it.
            if variant.includesDark {
                try write(icon, to: directory.appendingPathComponent("\(Int(point))\(suffix)_dark.png"))
            }
        }
    }
}

// Dock-tile images used by AppIconDockTilePlugin and the in-app icon picker.
let dockTile = drawDockIcon(artwork: artwork, mark: mark, size: 1024, badge: .none, drawsPlate: true)
try write(dockTile, to: assets.appendingPathComponent("AppIconLight.imageset/AppIconLight.png"))
try write(dockTile, to: assets.appendingPathComponent("AppIconDark.imageset/AppIconDark.png"))

// Menu-bar glyph: an alpha-only template so the status item follows the menu
// bar's own light/dark tinting. The artwork's gradient is dropped on purpose —
// a template image's color channels are ignored.
do {
    for (scale, suffix) in [(1, ""), (2, "@2x")] {
        let side = 18 * CGFloat(scale)
        guard let context = CGContext(
            data: nil,
            width: Int(side),
            height: Int(side),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { fatalError("no menu bar context") }
        context.interpolationQuality = .high
        // Draw the mark, then keep only its coverage: fill black through it.
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: 0, width: side, height: side), mask: mark)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.restoreGState()
        guard let glyph = context.makeImage() else { fatalError("no menu bar glyph") }
        try write(glyph, to: assets.appendingPathComponent("MenuBarIcon.imageset/MenuBarIcon\(suffix).png"))
    }
    let contents = """
    {
      "images" : [
        {
          "filename" : "MenuBarIcon.png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "filename" : "MenuBarIcon@2x.png",
          "idiom" : "universal",
          "scale" : "2x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "template-rendering-intent" : "template"
      }
    }
    """
    try contents.write(
        to: assets.appendingPathComponent("MenuBarIcon.imageset/Contents.json"),
        atomically: true,
        encoding: .utf8
    )
}

// Icon Composer layer: the mark alone on transparency, inset so macOS 26 can draw
// its own glass plate around it.
do {
    let side: CGFloat = 1024
    guard let context = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("no layer context") }
    context.interpolationQuality = .high
    let inset = side * 0.16
    context.draw(mark, in: CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2))
    guard let layer = context.makeImage() else { fatalError("no layer image") }
    try write(layer, to: root.appendingPathComponent("AppIcon.icon/Assets/fleet-icon-mark.png"))
}

print("fleet icons written")
