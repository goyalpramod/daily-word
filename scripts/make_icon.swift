// Renders the app icon: swift scripts/make_icon.swift <output.png>
// A single lowercase "w" in New York on blue-black ink.
import AppKit

let px = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let size = CGFloat(px)

NSColor(srgbRed: 0.149, green: 0.204, blue: 0.549, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let base = NSFont.systemFont(ofSize: 640, weight: .regular)
let serif = base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: 640) } ?? base
let style = NSMutableParagraphStyle(); style.alignment = .center
let text = NSAttributedString(string: "w", attributes: [
    .font: serif, .foregroundColor: NSColor.white, .paragraphStyle: style, .kern: -10,
])
// Center optically on the x-height rather than the full line box.
let xHeight = serif.xHeight
let baseline = (size - xHeight) / 2 - 10
text.draw(at: NSPoint(x: (size - text.size().width) / 2, y: baseline + serif.descender))

NSGraphicsContext.restoreGraphicsState()
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
