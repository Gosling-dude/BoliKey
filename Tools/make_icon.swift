// Draws the BoliKey icon: a speech bubble with a key-shaped "ब" mark, on an indigo to saffron field.
// Usage: swift Tools/make_icon.swift App/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import AppKit

let size = CGSize(width: 1024, height: 1024)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let colors = [CGColor(red: 0.16, green: 0.14, blue: 0.50, alpha: 1), CGColor(red: 0.42, green: 0.20, blue: 0.62, alpha: 1), CGColor(red: 1.0, green: 0.55, blue: 0.20, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

// Speech bubble.
let bubble = CGMutablePath()
bubble.addRoundedRect(in: CGRect(x: 172, y: 262, width: 680, height: 560), cornerWidth: 150, cornerHeight: 150)
bubble.move(to: CGPoint(x: 330, y: 290))
bubble.addLine(to: CGPoint(x: 280, y: 150))
bubble.addLine(to: CGPoint(x: 490, y: 280))
bubble.closeSubpath()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.98))
ctx.addPath(bubble)
ctx.fillPath()

// The mark.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Kohinoor Devanagari Medium", size: 400) ?? NSFont.systemFont(ofSize: 400, weight: .semibold),
    .foregroundColor: NSColor(red: 0.20, green: 0.18, blue: 0.56, alpha: 1),
    .paragraphStyle: paragraph,
]
NSAttributedString(string: "ब", attributes: attrs).draw(in: CGRect(x: 172, y: 310, width: 680, height: 500))

// A row of three keys under the mark, for "keyboard".
ctx.setFillColor(CGColor(red: 1.0, green: 0.55, blue: 0.20, alpha: 1))
for i in 0..<3 {
    ctx.addPath(CGPath(roundedRect: CGRect(x: 322 + i * 130, y: 322, width: 110, height: 44), cornerWidth: 14, cornerHeight: 14, transform: nil))
}
ctx.fillPath()
NSGraphicsContext.current = nil
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
