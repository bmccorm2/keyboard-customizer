import AppKit

// Run from the project root: swift tools/generate-menu-icon.swift
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent(".build/MenuIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for size in [16, 32] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.scaleBy(x: CGFloat(size) / 32, y: CGFloat(size) / 32)
    context.setStrokeColor(NSColor.white.cgColor)
    context.setFillColor(NSColor.white.cgColor)
    context.setLineWidth(2)
    context.addPath(CGPath(roundedRect: CGRect(x: 2, y: 6, width: 28, height: 20),
                           cornerWidth: 3, cornerHeight: 3, transform: nil))
    context.strokePath()
    for y in [15, 20] {
        for x in [6, 11, 16, 21] {
            context.fill(CGRect(x: x, y: y, width: 3, height: 2))
        }
    }
    context.fill(CGRect(x: 10, y: 10, width: 12, height: 2))

    var visible = 0
    var transparent = 0
    for y in 0..<size {
        for x in 0..<size {
            let color = bitmap.colorAt(x: x, y: y)!
            if color.alphaComponent == 0 { transparent += 1; continue }
            visible += 1
            precondition(color.redComponent > 0.99 && color.greenComponent > 0.99 && color.blueComponent > 0.99,
                         "Menu icon must contain only white artwork")
        }
    }
    precondition(visible > 0 && transparent > 0, "Menu icon needs artwork and a transparent background")
    let name = size == 16 ? "icon_16x16.png" : "icon_16x16@2x.png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
}

let output = root.appendingPathComponent(".build/MenuIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try task.run()
task.waitUntilExit()
precondition(task.terminationStatus == 0, "Could not package menu icon")
let data = try Data(contentsOf: output)
let resources = root.appendingPathComponent("Vendor/Colemak DH.bundle/Contents/Resources")
for url in try FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
    where url.pathExtension == "icns" {
    try data.write(to: url)
}
print("Updated all Colemak-DH menu icons (16px and 32px).")
