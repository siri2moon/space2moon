import SwiftUI

/// Night sky with drifting nebulae and twinkling stars.
struct ArcaneBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        let x, y, radius, phase, speed: Double
    }

    private static let stars: [Star] = {
        var rng = SplitMix64(state: 7)
        return (0..<170).map { _ in
            Star(
                x: .random(in: 0...1, using: &rng), y: .random(in: 0...1, using: &rng),
                radius: .random(in: 0.35...1.5, using: &rng), phase: .random(in: 0...(2 * .pi), using: &rng),
                speed: .random(in: 0.25...1.1, using: &rng))
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let full = Path(CGRect(origin: .zero, size: size))
                ctx.fill(full, with: .linearGradient(
                    Gradient(colors: [Arcana.night, Arcana.dusk, Arcana.night]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))

                let nebulae: [(Color, Double, Double, Double)] = [
                    (Arcana.violet, 0.22, 0.28, 0.17), (Arcana.cyan, 0.78, 0.72, 0.09), (Arcana.gold, 0.58, 0.12, 0.06),
                ]
                for (i, nebula) in nebulae.enumerated() {
                    let (color, nx, ny, strength) = nebula
                    let cx = size.width * nx + sin(t * 0.05 + Double(i) * 1.7) * 70
                    let cy = size.height * ny + cos(t * 0.04 + Double(i) * 2.3) * 50
                    let radius = max(size.width, size.height) * 0.5
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(
                            Gradient(colors: [color.opacity(strength), .clear]),
                            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: radius))
                }

                for star in Self.stars {
                    let twinkle = 0.5 + 0.5 * sin(t * star.speed + star.phase)
                    let rect = CGRect(
                        x: star.x * size.width, y: star.y * size.height,
                        width: star.radius * 2, height: star.radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.12 + 0.55 * twinkle)))
                }
            }
        }
    }
}

struct GaugeSegment: Identifiable {
    let id: String
    let fraction: Double
    let color: Color
}

/// The magic circle: rune rings around a gauge of the whole disk.
struct MagicCircle<Center: View>: View {
    let segments: [GaugeSegment]
    let scanning: Bool
    @ViewBuilder var center: Center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static var runes: [String] { "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟᚠᚢᚦᚨᚱᚲ".map(String.init) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                draw(in: &ctx, size: size, t: t)
            }
        }
        .overlay { center }
        .aspectRatio(1, contentMode: .fit)
    }

    private func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = min(size.width, size.height) / 2 - 6

        // Outer rings and the rune band between them.
        ctx.stroke(circle(c, R), with: .color(Arcana.gold.opacity(0.5)), lineWidth: 1)
        ctx.stroke(circle(c, R - 18), with: .color(Arcana.gold.opacity(0.3)), lineWidth: 0.8)
        let runes = Self.runes
        for (i, rune) in runes.enumerated() {
            let angle = t * 0.05 + Double(i) / Double(runes.count) * 2 * .pi
            var g = ctx
            g.translateBy(x: c.x + cos(angle) * (R - 9), y: c.y + sin(angle) * (R - 9))
            g.rotate(by: .radians(angle + .pi / 2))
            g.draw(Text(rune).font(.lore(12, .semibold)).foregroundStyle(Arcana.gold.opacity(0.8)), at: .zero)
        }

        // Counter-rotating tick ring.
        var ticks = Path()
        for i in 0..<96 {
            let angle = -t * 0.025 + Double(i) / 96 * 2 * .pi
            let length: CGFloat = i % 8 == 0 ? 7 : 3
            let r0 = R - 24
            ticks.move(to: CGPoint(x: c.x + cos(angle) * r0, y: c.y + sin(angle) * r0))
            ticks.addLine(to: CGPoint(x: c.x + cos(angle) * (r0 - length), y: c.y + sin(angle) * (r0 - length)))
        }
        ctx.stroke(ticks, with: .color(Arcana.gold.opacity(0.35)), lineWidth: 1)

        // The disk gauge.
        let ringR = R - 48
        let width: CGFloat = 17
        ctx.stroke(circle(c, ringR), with: .color(.white.opacity(0.06)), lineWidth: width)
        var start = -Double.pi / 2
        for segment in segments {
            let sweep = segment.fraction * 2 * .pi
            guard sweep > 0.003 else { continue }
            var arc = Path()
            let gap = min(0.008, sweep * 0.2)
            arc.addArc(center: c, radius: ringR, startAngle: .radians(start + gap), endAngle: .radians(start + sweep - gap), clockwise: false)
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 7))
                layer.stroke(arc, with: .color(segment.color.opacity(0.7)), lineWidth: width)
            }
            ctx.stroke(arc, with: .color(segment.color), style: StrokeStyle(lineWidth: width, lineCap: .butt))
            start += sweep
        }

        if scanning {
            let head = t * 2.2
            var sweep = Path()
            sweep.addArc(center: c, radius: ringR, startAngle: .radians(head), endAngle: .radians(head + 1.1), clockwise: false)
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 10))
                layer.stroke(sweep, with: .color(Arcana.cyan.opacity(0.8)), lineWidth: width + 8)
            }
        }

        // Hexagram at the heart of the circle.
        let hexR = ringR - 26
        ctx.stroke(circle(c, hexR), with: .color(Arcana.violet.opacity(0.25)), lineWidth: 0.8)
        let spin = t * 0.015
        for offset in [0.0, Double.pi] {
            var triangle = Path()
            for k in 0..<3 {
                let angle = spin + offset + Double(k) * 2 * .pi / 3 - .pi / 2
                let p = CGPoint(x: c.x + cos(angle) * hexR, y: c.y + sin(angle) * hexR)
                k == 0 ? triangle.move(to: p) : triangle.addLine(to: p)
            }
            triangle.closeSubpath()
            ctx.stroke(triangle, with: .color(Arcana.violet.opacity(0.16)), lineWidth: 0.8)
        }
    }
}

/// A burst of light when space is reclaimed.
struct SparkBurst: View {
    let start = Date.now

    private struct Spark {
        let angle, speed, size, hue: Double
    }

    private static let sparks: [Spark] = {
        var rng = SplitMix64(state: 42)
        return (0..<110).map { _ in
            Spark(
                angle: .random(in: 0...(2 * .pi), using: &rng), speed: .random(in: 120...520, using: &rng),
                size: .random(in: 1.5...4.5, using: &rng), hue: .random(in: 0...1, using: &rng))
        }
    }()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let progress = min(1, elapsed / 1.8)
                let eased = 1 - pow(1 - progress, 3)
                ctx.addFilter(.blur(radius: 0.6))
                for spark in Self.sparks {
                    let distance = spark.speed * eased
                    let p = CGPoint(x: c.x + cos(spark.angle) * distance, y: c.y + sin(spark.angle) * distance)
                    let color = spark.hue < 0.4 ? Arcana.cyan : spark.hue < 0.75 ? Arcana.violet : Arcana.gold
                    let s = spark.size * (1 - progress * 0.6)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)),
                        with: .color(color.opacity(1 - progress)))
                }
                let ringR = 40 + 260 * eased
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: ringR * 2, height: ringR * 2)),
                    with: .color(Arcana.cyan.opacity(0.5 * (1 - progress))), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}
