import MageCore
import SwiftUI

/// The arcane palette: a night sky, violet magic, cyan light and old gold.
enum Arcana {
    static let night = Color(red: 0.035, green: 0.027, blue: 0.105)
    static let dusk = Color(red: 0.10, green: 0.06, blue: 0.23)
    static let violet = Color(red: 0.62, green: 0.42, blue: 1.0)
    static let indigo = Color(red: 0.33, green: 0.40, blue: 1.0)
    static let cyan = Color(red: 0.37, green: 0.92, blue: 0.83)
    static let gold = Color(red: 0.91, green: 0.77, blue: 0.42)
    static let ember = Color(red: 0.98, green: 0.45, blue: 0.29)
    static let ink = Color.white.opacity(0.94)
    static let mist = Color.white.opacity(0.64)
    static let faint = Color.white.opacity(0.38)
    static let glass = Color.white.opacity(0.045)
    static let hairline = Color.white.opacity(0.10)

    static func color(_ id: CategoryID) -> Color {
        switch id {
        case .trash: Color(red: 0.72, green: 0.66, blue: 0.88)
        case .userCaches: violet
        case .logs: Color(red: 0.55, green: 0.62, blue: 1.0)
        case .xcode: Color(red: 0.30, green: 0.55, blue: 1.0)
        case .devCaches: Color(red: 0.66, green: 0.90, blue: 0.36)
        case .iosBackups: Color(red: 0.98, green: 0.52, blue: 0.78)
        case .mail: Color(red: 0.38, green: 0.80, blue: 1.0)
        case .messages: Color(red: 0.30, green: 0.92, blue: 0.62)
        case .downloads: cyan
        case .largeFiles: ember
        case .snapshots: gold
        case .docker: Color(red: 0.20, green: 0.70, blue: 0.90)
        case .system: Color(red: 0.75, green: 0.75, blue: 0.82)
        }
    }

    static func verdict(_ v: Verdict) -> (label: String, color: Color) {
        switch v {
        case .safe: ("SAFE TO BANISH", cyan)
        case .review: ("REVIEW FIRST", gold)
        case .guided: ("GUIDED RITUAL", violet)
        case .info: ("FOR KNOWLEDGE", faint)
        }
    }
}

extension Font {
    /// Titles, labels and numbers: SF Pro Rounded, soft and native to macOS.
    static func spell(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The app's name.
    static func sigilTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Running text. Sizes were tuned for a book face, so scale them back down.
    static func lore(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: (size - 1.5).rounded(), weight: weight == .medium ? .regular : weight, design: .rounded)
    }
}

struct GlowButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.spell(12.5, .bold))
            .foregroundStyle(prominent ? Color.white : Arcana.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                if prominent {
                    Capsule().fill(LinearGradient(colors: [Arcana.violet, Arcana.indigo], startPoint: .leading, endPoint: .trailing))
                } else {
                    Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07))
                }
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(prominent ? 0.28 : 0.12), lineWidth: 1))
            .shadow(color: prominent ? Arcana.violet.opacity(0.55) : .clear, radius: configuration.isPressed ? 5 : 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(duration: 0.22, bounce: 0.3), value: configuration.isPressed)
            .contentShape(Capsule())
            .focusEffectDisabled()
    }
}

/// A category's symbol inside a softly glowing seal.
struct Sigil: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.13))
            Circle().strokeBorder(color.opacity(0.45), lineWidth: 1)
            Circle().strokeBorder(color.opacity(0.18), lineWidth: 1).padding(4)
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.35), radius: 8)
    }
}

struct VerdictChip: View {
    let verdict: Verdict

    var body: some View {
        let v = Arcana.verdict(verdict)
        Text(v.label)
            .font(.spell(9.5, .bold))
            .tracking(1.1)
            .foregroundStyle(v.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(v.color.opacity(0.1)))
            .overlay(Capsule().strokeBorder(v.color.opacity(0.3), lineWidth: 0.5))
    }
}

/// Glass panel with a faint gradient rim, used for cards and bars.
struct ArcanePanel: ViewModifier {
    var radius: CGFloat = 16
    var glow: Color = .clear
    var lit = false

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Arcana.glass))
            // A dark core under the glass keeps text readable over any background.
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Arcana.night.opacity(0.62)))
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial).opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(lit ? 0.32 : 0.16), glow.opacity(lit ? 0.5 : 0.12), Color.white.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
            )
            .shadow(color: glow.opacity(lit ? 0.35 : 0), radius: 18)
    }
}

extension View {
    func arcanePanel(radius: CGFloat = 16, glow: Color = .clear, lit: Bool = false) -> some View {
        modifier(ArcanePanel(radius: radius, glow: glow, lit: lit))
    }
}

/// Text that breathes while something is being measured.
struct Scrying: View {
    var label = "Scrying…"

    var body: some View {
        Text(label)
            .font(.lore(17).italic())
            .foregroundStyle(Arcana.mist)
            .phaseAnimator([0.35, 1.0]) { view, phase in
                view.opacity(phase)
            } animation: { _ in .easeInOut(duration: 0.9) }
    }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Paintings made with Meta Muse (scripts/muse-art.sh) and the logo built from them.
/// Every view works without them.
enum ArtLibrary {
    static func image(_ name: String) -> NSImage? {
        let bundled = Bundle.main.resourceURL?.appending(path: "\(name).png")
        let source = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../Resources/\(name).png").standardizedFileURL
        for url in [bundled, source].compactMap({ $0 }) {
            if let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    static let sanctum = image("Art/sanctum")
    static let mage = image("Brand/mage")
    static let emblem = image("Brand/emblem")
}

/// The Muse-painted mage (Siri as a wizard): floats, sways, glows and
/// trails sparkles. Still when Reduce Motion is on.
struct FloatingMage: View {
    var size: CGFloat = 120
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Sparkle {
        let orbit, speed, phase, size, hue: Double
    }

    private static let sparkles: [Sparkle] = {
        var rng = SplitMix64(state: 11)
        return (0..<16).map { _ in
            Sparkle(
                orbit: .random(in: 0.34...0.56, using: &rng), speed: .random(in: 0.25...0.7, using: &rng),
                phase: .random(in: 0...(2 * .pi), using: &rng), size: .random(in: 1.5...3.5, using: &rng),
                hue: .random(in: 0...1, using: &rng))
        }
    }()

    var body: some View {
        if let mage = ArtLibrary.mage {
            TimelineView(.animation(minimumInterval: 1 / 40, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.5 + 0.5 * sin(t * 1.6)
                ZStack {
                    // Soft aura behind the mage.
                    Circle()
                        .fill(RadialGradient(
                            colors: [Arcana.cyan.opacity(0.18 + 0.12 * pulse), Arcana.violet.opacity(0.08), .clear],
                            center: .center, startRadius: 0, endRadius: size * 0.55))
                        .frame(width: size * 1.2, height: size * 1.2)

                    // Sparkles orbiting and twinkling.
                    Canvas { ctx, canvas in
                        let c = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                        for s in Self.sparkles {
                            let angle = s.phase + t * s.speed
                            let r = s.orbit * canvas.width
                            let p = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r * 0.75)
                            let twinkle = 0.5 + 0.5 * sin(t * 3 + s.phase * 4)
                            let d = s.size * (0.6 + 0.6 * twinkle)
                            let color = s.hue < 0.5 ? Arcana.cyan : s.hue < 0.8 ? Arcana.gold : Arcana.violet
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)),
                                     with: .color(color.opacity(0.35 + 0.6 * twinkle)))
                        }
                    }
                    .frame(width: size * 1.3, height: size * 1.3)

                    Image(nsImage: mage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(sin(t * 0.9) * 4), anchor: .bottom)
                        .scaleEffect(1 + 0.025 * sin(t * 1.3))
                        .offset(y: sin(t * 1.2) * 6)
                        .shadow(color: Arcana.cyan.opacity(0.25 + 0.3 * pulse), radius: 14)
                }
            }
            .frame(width: size * 1.3, height: size * 1.3)
            .allowsHitTesting(false)
        }
    }
}
