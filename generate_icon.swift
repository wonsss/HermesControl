#!/usr/bin/env swift
import AppKit

func makeIcon(_ px: Int) -> Data {
    let size = CGFloat(px)
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    // Teal gradient background
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let grad = NSGradient(colors: [
        NSColor(red: 0.08, green: 0.72, blue: 0.62, alpha: 1),
        NSColor(red: 0.04, green: 0.48, blue: 0.44, alpha: 1),
    ])!
    grad.draw(in: bg, angle: -90)

    // White antenna waves (3 arcs, centered)
    let cx = size * 0.5
    let cy = size * 0.44
    NSColor.white.setStroke()
    NSColor.white.setFill()

    // Center dot
    let dotR = size * 0.055
    let dot = NSBezierPath(ovalIn: NSRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))
    dot.fill()

    // Stem
    let stemW = size * 0.06
    let stemH = size * 0.20
    let stem = NSBezierPath(roundedRect: NSRect(x: cx - stemW / 2, y: cy - stemH, width: stemW, height: stemH),
                             xRadius: stemW / 2, yRadius: stemW / 2)
    stem.fill()

    // 3 arcs radiating outward
    let lineW = size * 0.055
    for (i, r) in [(size * 0.14), (size * 0.24), (size * 0.34)].enumerated() {
        _ = i
        let arc = NSBezierPath()
        arc.lineWidth = lineW
        arc.lineCapStyle = .round
        arc.appendArc(withCenter: NSPoint(x: cx, y: cy),
                      radius: r,
                      startAngle: 210, endAngle: 330,
                      clockwise: true)
        arc.stroke()
    }

    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let sizes = [16, 32, 128, 256, 512]
let fm = FileManager.default
try? fm.createDirectory(atPath: "HermesControl.iconset", withIntermediateDirectories: true)

for px in sizes {
    let data = makeIcon(px)
    try! data.write(to: URL(fileURLWithPath: "HermesControl.iconset/icon_\(px)x\(px).png"))
    let data2x = makeIcon(px * 2)
    try! data2x.write(to: URL(fileURLWithPath: "HermesControl.iconset/icon_\(px)x\(px)@2x.png"))
}
print("✓ iconset generated")
