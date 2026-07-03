#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Renders the Veil app icon at 1024×1024 and writes a PNG. The macOS iconset
// (all sizes + .icns) is assembled by make-icon.sh using sips/iconutil.

let size = 1024
let scale = CGFloat(size)

guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("context")
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

// Rounded-rect background with a vertical indigo→violet gradient (macOS squircle-ish).
let radius = scale * 0.224
let bgRect = CGRect(x: 0, y: 0, width: scale, height: scale)
let bgPath = CGPath(roundedRect: bgRect.insetBy(dx: scale*0.04, dy: scale*0.04),
                    cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                      colors: [color(99, 102, 241), color(124, 58, 237)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: scale),
                       end: CGPoint(x: scale, y: 0), options: [])
ctx.restoreGState()

// Shield silhouette, centered.
let cx = scale/2
let topY = scale*0.80
let botY = scale*0.20
let w = scale*0.32
let shield = CGMutablePath()
shield.move(to: CGPoint(x: cx, y: topY))
shield.addLine(to: CGPoint(x: cx - w, y: topY - scale*0.10))
shield.addLine(to: CGPoint(x: cx - w, y: scale*0.45))
shield.addQuadCurve(to: CGPoint(x: cx, y: botY),
                    control: CGPoint(x: cx - w, y: botY + scale*0.02))
shield.addQuadCurve(to: CGPoint(x: cx + w, y: scale*0.45),
                    control: CGPoint(x: cx + w, y: botY + scale*0.02))
shield.addLine(to: CGPoint(x: cx + w, y: topY - scale*0.10))
shield.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -scale*0.012), blur: scale*0.03,
              color: color(0, 0, 0, 0.25))
ctx.addPath(shield)
ctx.setFillColor(color(255, 255, 255, 0.96))
ctx.fillPath()
ctx.restoreGState()

// Stylized "V" cut through the shield.
let vPath = CGMutablePath()
let vTop = topY - scale*0.06
let vBot = botY + scale*0.10
let vHalf = w*0.52
vPath.move(to: CGPoint(x: cx - vHalf, y: vTop))
vPath.addLine(to: CGPoint(x: cx - vHalf*0.42, y: vTop))
vPath.addLine(to: CGPoint(x: cx, y: vBot + scale*0.07))
vPath.addLine(to: CGPoint(x: cx + vHalf*0.42, y: vTop))
vPath.addLine(to: CGPoint(x: cx + vHalf, y: vTop))
vPath.addLine(to: CGPoint(x: cx, y: vBot))
vPath.closeSubpath()
ctx.addPath(vPath)
ctx.setFillColor(color(124, 58, 237))
ctx.fillPath()

guard let image = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
