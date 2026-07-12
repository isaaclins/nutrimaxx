import AppKit

// Renders a native-style iOS app icon: gradient background + centered white SF Symbol.
// Usage: swift render_icon.swift <output.png> [sfSymbolName]

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let symbolName = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "fork.knife"
let side: CGFloat = 1024

let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

// Background gradient (top lighter, bottom darker) — Apple system-icon feel.
let top = NSColor(red: 0.26, green: 0.85, blue: 0.52, alpha: 1)     // fresh green
let bottom = NSColor(red: 0.07, green: 0.60, blue: 0.33, alpha: 1)  // deeper green
let gradient = NSGradient(colors: [top, bottom])!
gradient.draw(in: NSRect(x: 0, y: 0, width: side, height: side), angle: -90)

// Soft top highlight for depth.
let highlight = NSGradient(colors: [NSColor(white: 1, alpha: 0.22), NSColor(white: 1, alpha: 0)])!
highlight.draw(in: NSRect(x: 0, y: 0, width: side, height: side), angle: -90)

// White SF Symbol glyph, centered, with a subtle drop shadow.
let config = NSImage.SymbolConfiguration(pointSize: 560, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
    fatalError("symbol \(symbolName) unavailable")
}

let maxBox: CGFloat = 520
let s = symbol.size
let scale = min(maxBox / s.width, maxBox / s.height)
let w = s.width * scale, h = s.height * scale
let target = NSRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h)

let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0, alpha: 0.25)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 28
shadow.set()

symbol.draw(in: target)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) with symbol \(symbolName)")
