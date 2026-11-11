import AppKit

// Package the user-supplied artwork at Apple's required icon sizes.
let source = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("local-assets/AppIcon.png").path
let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let catalog = project.appendingPathComponent("Resources/Assets.xcassets")
let output = catalog.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
guard let image = NSImage(contentsOfFile: source),
      let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                              bytesPerRow: 1024 * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not read the supplied icon")
}
context.setFillColor(NSColor.black.cgColor)
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current?.imageInterpolation = .high
// Leave room for the iPad's rounded icon mask without clipping the artwork.
image.draw(in: NSRect(x: 64, y: 64, width: 896, height: 896), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
guard let master = context.makeImage() else { fatalError("Could not render the icon") }
let slots: [(String, String, String)] = [
    ("iphone", "20x20", "2x"), ("iphone", "20x20", "3x"),
    ("iphone", "29x29", "2x"), ("iphone", "29x29", "3x"),
    ("iphone", "40x40", "2x"), ("iphone", "40x40", "3x"),
    ("iphone", "60x60", "2x"), ("iphone", "60x60", "3x"),
    ("ipad", "20x20", "1x"), ("ipad", "20x20", "2x"),
    ("ipad", "29x29", "1x"), ("ipad", "29x29", "2x"),
    ("ipad", "40x40", "1x"), ("ipad", "40x40", "2x"),
    ("ipad", "76x76", "1x"), ("ipad", "76x76", "2x"),
    ("ipad", "83.5x83.5", "2x"), ("ios-marketing", "1024x1024", "1x")
]
var images: [[String: String]] = []
for (idiom, size, scale) in slots {
    let pixels = Int(Double(size.components(separatedBy: "x")[0])! * Double(scale.dropLast())!)
    let bitmap = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                           bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    bitmap.interpolationQuality = .high
    bitmap.draw(master, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let filename = "AppIcon-\(size)@\(scale).png"
    let png = NSBitmapImageRep(cgImage: bitmap.makeImage()!).representation(using: .png, properties: [:])!
    try png.write(to: output.appendingPathComponent(filename))
    images.append(["idiom": idiom, "size": size, "scale": scale, "filename": filename])
}
let info: [String: Any] = ["info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: catalog.appendingPathComponent("Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": info["info"]!, "images": images], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
print(output.path)
