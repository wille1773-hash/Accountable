import AppKit
import CoreGraphics

// Accountable icon: a deep green ring that's almost closed, with a dot sitting in the gap.
// The open loop is the time you asked for; the dot is you, keeping your word.
func render(size: CGFloat, dark: Bool, path: String) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    func rgb(_ hex: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    ctx.setFillColor(rgb(dark ? 0x151A17 : 0xF3F5EF))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let c = CGPoint(x: size / 2, y: size / 2)
    let r = size * 0.27
    let line = size * 0.105
    let terracotta = rgb(dark ? 0x6CC79A : 0x2F7A58)
    // Gap centered at the top-right (about 1 o'clock). CoreGraphics angles are counterclockwise from +x.
    let gapCenter = CGFloat.pi / 2 - CGFloat.pi / 7
    let gapHalf: CGFloat = 0.40
    ctx.setStrokeColor(terracotta)
    ctx.setLineWidth(line)
    ctx.setLineCap(.round)
    ctx.addArc(center: c, radius: r, startAngle: gapCenter + gapHalf, endAngle: gapCenter - gapHalf + 2 * .pi, clockwise: false)
    ctx.strokePath()

    // The dot, slightly outside the ring's path, in the gap.
    let dotR = line * 0.5
    let dotDist = r
    let dot = CGPoint(x: c.x + cos(gapCenter) * dotDist, y: c.y + sin(gapCenter) * dotDist)
    ctx.setFillColor(rgb(dark ? 0xEEF2EC : 0x1C2420))
    ctx.fillEllipse(in: CGRect(x: dot.x - dotR, y: dot.y - dotR, width: dotR * 2, height: dotR * 2))

    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
render(size: 1024, dark: false, path: "AppIcon.png")
render(size: 1024, dark: true, path: "AppIcon-dark.png")
