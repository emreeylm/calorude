import AppKit
import Foundation

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 24)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(red: 0.07, green: 0.09, blue: 0.07, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let lime = NSColor(red: 0.78, green: 0.96, blue: 0.28, alpha: 1)
lime.setStroke()
let plate = NSBezierPath(ovalIn: NSRect(x: 196, y: 196, width: 632, height: 632))
plate.lineWidth = 48
plate.stroke()
lime.setFill()
let bolt = NSBezierPath()
bolt.move(to: NSPoint(x: 555, y: 820))
bolt.line(to: NSPoint(x: 333, y: 466))
bolt.line(to: NSPoint(x: 488, y: 466))
bolt.line(to: NSPoint(x: 449, y: 210))
bolt.line(to: NSPoint(x: 704, y: 574))
bolt.line(to: NSPoint(x: 536, y: 574))
bolt.close()
bolt.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
