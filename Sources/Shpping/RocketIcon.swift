import AppKit

/// Zelfgetekend raket-icoon voor de menubalk (template, dus past zich aan licht/donker aan).
/// Uit: raket in omtrek. Tijdens focus: gevulde raket met vlammetje.
enum RocketIcon {
    static func image(launched: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            let t = NSAffineTransform()
            t.translateX(by: 9, yBy: 9)
            t.rotate(byDegrees: -45)          // schuin omhoog, richting rechtsboven
            t.scale(by: 0.92)
            t.translateX(by: -9, yBy: -9.4)
            t.concat()

            NSColor.black.set()

            // Romp
            let body = NSBezierPath()
            body.move(to: NSPoint(x: 9, y: 17.4))
            body.curve(to: NSPoint(x: 11.9, y: 9.2), controlPoint1: NSPoint(x: 11.3, y: 15.6), controlPoint2: NSPoint(x: 11.9, y: 12.3))
            body.line(to: NSPoint(x: 11.9, y: 5.8))
            body.line(to: NSPoint(x: 6.1, y: 5.8))
            body.line(to: NSPoint(x: 6.1, y: 9.2))
            body.curve(to: NSPoint(x: 9, y: 17.4), controlPoint1: NSPoint(x: 6.1, y: 12.3), controlPoint2: NSPoint(x: 6.7, y: 15.6))
            body.close()

            // Vinnen
            let fins = NSBezierPath()
            fins.move(to: NSPoint(x: 6.1, y: 9.6)); fins.line(to: NSPoint(x: 3.6, y: 6.6))
            fins.line(to: NSPoint(x: 3.6, y: 4.0)); fins.line(to: NSPoint(x: 6.1, y: 5.8))
            fins.move(to: NSPoint(x: 11.9, y: 9.6)); fins.line(to: NSPoint(x: 14.4, y: 6.6))
            fins.line(to: NSPoint(x: 14.4, y: 4.0)); fins.line(to: NSPoint(x: 11.9, y: 5.8))

            // Raampje
            let window = NSBezierPath(ovalIn: NSRect(x: 7.6, y: 10.4, width: 2.8, height: 2.8))

            if launched {
                let filled = NSBezierPath()
                filled.append(body)
                filled.append(window)
                filled.windingRule = .evenOdd   // raampje blijft open
                filled.fill()
                fins.close()
                fins.fill()
                // Vlammetje
                let flame = NSBezierPath()
                flame.move(to: NSPoint(x: 7.4, y: 5.0))
                flame.curve(to: NSPoint(x: 9, y: 0.6), controlPoint1: NSPoint(x: 7.4, y: 3.2), controlPoint2: NSPoint(x: 8.4, y: 2.0))
                flame.curve(to: NSPoint(x: 10.6, y: 5.0), controlPoint1: NSPoint(x: 9.6, y: 2.0), controlPoint2: NSPoint(x: 10.6, y: 3.2))
                flame.close()
                flame.fill()
            } else {
                for p in [body, fins, window] {
                    p.lineWidth = 1.3
                    p.lineJoinStyle = .round
                    p.lineCapStyle = .round
                    p.stroke()
                }
            }
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Shpping"
        return img
    }
}
