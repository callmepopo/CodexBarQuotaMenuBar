import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: swift make_app_icon.swift <output.icns>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("CodexBarQuotaMenuBar-\(UUID().uuidString).iconset")

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer {
    try? fileManager.removeItem(at: iconsetURL)
}

let iconFiles: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for iconFile in iconFiles {
    let pixels = Int(iconFile.points * iconFile.scale)
    let image = drawIcon(size: CGSize(width: pixels, height: pixels))
    let destination = iconsetURL.appendingPathComponent(iconFile.name)
    try writePNG(image, to: destination)
}

try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}

private func drawIcon(size: CGSize) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = CGRect(origin: .zero, size: size)
    let scale = size.width / 1024
    let cornerRadius = 220 * scale

    NSColor.clear.setFill()
    rect.fill()

    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    backgroundPath.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.25, green: 0.42, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.38, green: 0.28, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.25, alpha: 1)
    ])
    gradient?.draw(in: rect, angle: -35)

    NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
    let border = NSBezierPath(
        roundedRect: rect.insetBy(dx: 28 * scale, dy: 28 * scale),
        xRadius: 190 * scale,
        yRadius: 190 * scale
    )
    border.lineWidth = 10 * scale
    border.stroke()

    drawQuotaRing(in: rect, scale: scale)
    drawProgressBars(in: rect, scale: scale)

    return image
}

private func drawQuotaRing(in rect: CGRect, scale: CGFloat) {
    let center = CGPoint(x: rect.midX, y: rect.midY + 58 * scale)
    let radius = 236 * scale
    let lineWidth = 76 * scale
    let ringRect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )

    NSColor(calibratedWhite: 1, alpha: 0.24).setStroke()
    let baseRing = NSBezierPath(ovalIn: ringRect)
    baseRing.lineWidth = lineWidth
    baseRing.stroke()

    NSColor(calibratedRed: 0.45, green: 0.96, blue: 0.58, alpha: 1).setStroke()
    let progressRing = NSBezierPath()
    progressRing.appendArc(
        withCenter: center,
        radius: radius,
        startAngle: -88,
        endAngle: 164,
        clockwise: false
    )
    progressRing.lineCapStyle = .round
    progressRing.lineWidth = lineWidth
    progressRing.stroke()

    NSColor.white.setStroke()
    let check = NSBezierPath()
    check.move(to: CGPoint(x: center.x - 105 * scale, y: center.y - 6 * scale))
    check.line(to: CGPoint(x: center.x - 28 * scale, y: center.y - 84 * scale))
    check.line(to: CGPoint(x: center.x + 126 * scale, y: center.y + 90 * scale))
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.lineWidth = 60 * scale
    check.stroke()
}

private func drawProgressBars(in rect: CGRect, scale: CGFloat) {
    let width = 560 * scale
    let height = 64 * scale
    let x = rect.midX - width / 2

    drawBar(frame: CGRect(x: x, y: 166 * scale, width: width, height: height), fillPercent: 0.68, scale: scale)
    drawBar(frame: CGRect(x: x, y: 86 * scale, width: width, height: height), fillPercent: 0.34, scale: scale)
}

private func drawBar(frame: CGRect, fillPercent: CGFloat, scale: CGFloat) {
    let radius = frame.height / 2
    let background = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    NSColor(calibratedWhite: 1, alpha: 0.22).setFill()
    background.fill()

    let fillFrame = CGRect(
        x: frame.minX,
        y: frame.minY,
        width: max(frame.height, frame.width * fillPercent),
        height: frame.height
    )
    let fill = NSBezierPath(roundedRect: fillFrame, xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.45, green: 0.96, blue: 0.58, alpha: 1).setFill()
    fill.fill()

    NSColor(calibratedWhite: 1, alpha: 0.28).setStroke()
    background.lineWidth = 6 * scale
    background.stroke()
}

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "CodexBarQuotaMenuBarIcon", code: 1)
    }

    try pngData.write(to: url)
}
