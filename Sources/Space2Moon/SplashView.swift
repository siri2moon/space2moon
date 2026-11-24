import SwiftUI

/// The first screen: the mage, the name and a moment of magic while the
/// first scan starts underneath. Click or press any key to skip.
struct SplashView: View {
    var onFinish: () -> Void
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ArcaneBackground()
            RadialGradient(
                colors: [Arcana.violet.opacity(0.22), Arcana.night.opacity(0.0)],
                center: .center, startRadius: 40, endRadius: 520)

            VStack(spacing: 18) {
                FloatingMage(size: 230)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .animation(.spring(duration: 0.9, bounce: 0.3), value: appeared)

                HStack(spacing: 12) {
                    if let emblem = ArtLibrary.emblem {
                        Image(nsImage: emblem)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .shadow(color: Arcana.cyan.opacity(0.6), radius: 12)
                    }
                    Text("Space2Moon")
                        .font(.sigilTitle(46))
                        .foregroundStyle(Arcana.ink)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.easeOut(duration: 0.7).delay(0.25), value: appeared)

                Text("Send your junk to the moon")
                    .font(.lore(18))
                    .foregroundStyle(Arcana.mist)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.7).delay(0.45), value: appeared)

                VStack(spacing: 10) {
                    ShimmerBar()
                        .frame(width: 220, height: 3)
                    Scrying(label: "Opening the grimoire…")
                }
                .padding(.top, 18)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.7), value: appeared)
            }

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("Crafted by").font(.lore(13))
                    Image(systemName: "moon.stars.fill").font(.system(size: 10))
                    Text("siri2moon").font(.spell(12, .bold))
                }
                .foregroundStyle(Arcana.faint)
                .padding(.bottom, 28)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.9), value: appeared)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onFinish() }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress { _ in
            onFinish()
            return .handled
        }
        .task {
            appeared = true
            try? await Task.sleep(for: .seconds(reduceMotion ? 2 : 5))
            onFinish()
        }
    }
}

/// A thin bar with light running through it.
struct ShimmerBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let w = proxy.size.width
                let head = CGFloat((t * 0.7).truncatingRemainder(dividingBy: 1.4)) * w * 1.4 - w * 0.2
                Capsule().fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [.clear, Arcana.cyan, Arcana.violet, .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: w * 0.45)
                            .offset(x: head - w * 0.225)
                            .shadow(color: Arcana.cyan, radius: 6)
                    }
                    .clipShape(Capsule())
            }
        }
    }
}
