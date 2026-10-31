#if os(macOS)
import AppKit

/// A monochrome tracing of the interlocking loops in Kumone's app icon.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 11.9, y: 15.5))
            path.curve(to: NSPoint(x: 12.7, y: 2.2),
                       controlPoint1: NSPoint(x: 17.8, y: 12.8), controlPoint2: NSPoint(x: 18.3, y: 5.4))
            path.curve(to: NSPoint(x: 1.9, y: 8.7),
                       controlPoint1: NSPoint(x: 8.2, y: -0.4), controlPoint2: NSPoint(x: 1.8, y: 2.8))
            path.curve(to: NSPoint(x: 9.4, y: 12.9),
                       controlPoint1: NSPoint(x: 1.8, y: 13.7), controlPoint2: NSPoint(x: 5.1, y: 15.2))
            path.curve(to: NSPoint(x: 11.2, y: 6.2),
                       controlPoint1: NSPoint(x: 12.5, y: 11.1), controlPoint2: NSPoint(x: 13.1, y: 7.8))
            path.curve(to: NSPoint(x: 6.5, y: 7.9),
                       controlPoint1: NSPoint(x: 9.1, y: 4.1), controlPoint2: NSPoint(x: 6.7, y: 5.7))
            path.curve(to: NSPoint(x: 6.8, y: 16.9),
                       controlPoint1: NSPoint(x: 6.2, y: 10.3), controlPoint2: NSPoint(x: 9.9, y: 16.4))
            path.curve(to: NSPoint(x: 4.7, y: 16.3),
                       controlPoint1: NSPoint(x: 5.7, y: 17.1), controlPoint2: NSPoint(x: 5.0, y: 16.6))
            path.lineWidth = 1.7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Kumone"
        return image
    }()
}
#endif
