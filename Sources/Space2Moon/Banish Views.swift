import MageCore
import SwiftUI

/// Floating bar with what is chosen and the button that starts the cleaning.
/// Inside a category it banishes only that category, so items chosen
/// elsewhere (caches are chosen by default) never leave by surprise.
struct BanishBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let total = model.chosenBytes
        let here = model.focused
        let hereItems = here.map(model.chosen(in:)) ?? []
        let hereBytes = hereItems.reduce(0) { $0 + $1.size }
        let local = here != nil && !hereItems.isEmpty
        let elsewhere = total - (local ? hereBytes : 0)

        if total > 0 || model.banishing {
            HStack(spacing: 16) {
                Image(systemName: "wand.and.stars")
                    .font(.lore(20))
                    .foregroundStyle(LinearGradient(colors: [Arcana.gold, Arcana.cyan], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 1) {
                    Text((local ? hereBytes : total).bytesText)
                        .font(.spell(18, .bold))
                        .monospacedDigit()
                        .foregroundStyle(Arcana.ink)
                        .contentTransition(.numericText())
                    Group {
                        if local, let here {
                            Text("\(hereItems.count) items in \(Grimoire.info(here).title)")
                        } else if here != nil {
                            Text("\(model.chosen.count) items chosen in other places")
                        } else {
                            Text("\(model.chosen.count) items ready to banish")
                        }
                    }
                    .font(.lore(13))
                    .foregroundStyle(Arcana.mist)
                    .lineLimit(1)
                }
                Spacer(minLength: 12)
                if local, elsewhere > 0 {
                    Button("All \(total.bytesText)") { model.confirmBanish(nil) }
                        .buttonStyle(GlowButtonStyle(prominent: false))
                        .disabled(model.banishing)
                        .help("Banish everything chosen, in every category")
                }
                Button {
                    model.confirmBanish(local ? here : nil)
                } label: {
                    HStack(spacing: 6) {
                        if model.banishing { ProgressView().controlSize(.small) }
                        Text(model.banishing ? "Banishing…" : "Banish")
                    }
                    .frame(minWidth: 96)
                }
                .buttonStyle(GlowButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.banishing)
            }
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: 620)
            .background(Capsule().fill(Arcana.night.opacity(0.85)))
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(
                LinearGradient(colors: [Arcana.violet.opacity(0.7), Arcana.cyan.opacity(0.4)], startPoint: .leading, endPoint: .trailing),
                lineWidth: 1))
            .shadow(color: Arcana.violet.opacity(0.35), radius: 24, y: 6)
            .padding(.horizontal, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct ConfirmBanish: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let items = model.banishList
        let bytes = items.reduce(0) { $0 + $1.size }
        let groups = model.scope == nil ? model.chosenByCategory : []
        let erased = items.filter { $0.method == .delete }
        let trashed = items.filter { $0.method == .trash }

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Sigil(symbol: "wand.and.stars", color: Arcana.violet, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cast the banishing?").font(.spell(22, .bold)).foregroundStyle(Arcana.ink)
                    Text(model.scope.map { "\(bytes.bytesText) will leave \(Grimoire.info($0).title)" }
                         ?? "\(bytes.bytesText) will leave your disk")
                        .font(.lore(14.5)).foregroundStyle(Arcana.mist)
                }
            }
            VStack(spacing: 8) {
                if !erased.isEmpty {
                    row("flame", Arcana.ember, "Erased for good", "Caches, logs and data apps rebuild", erased)
                }
                if !trashed.isEmpty {
                    row("trash", Arcana.gold, "Moved to the Trash", "Your files, restorable until the Trash is emptied", trashed)
                }
            }
            if groups.count > 1 {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FROM").font(.spell(11, .bold)).tracking(1.2).foregroundStyle(Arcana.faint)
                    ForEach(groups, id: \.id) { group in
                        HStack {
                            Text(Grimoire.info(group.id).title)
                            Spacer()
                            Text(group.items.reduce(0) { $0 + $1.size }.bytesText).monospacedDigit()
                        }
                        .font(.lore(13.5))
                        .foregroundStyle(Arcana.mist)
                    }
                }
            }
            Text("Quit browsers, Xcode and other heavy apps first so their caches can be removed cleanly.")
                .font(.lore(13.5))
                .foregroundStyle(Arcana.faint)
            HStack {
                Spacer()
                Button("Not now") { dismiss() }
                    .buttonStyle(GlowButtonStyle(prominent: false))
                    .keyboardShortcut(.cancelAction)
                Button("Banish") {
                    dismiss()
                    Task { await model.banish() }
                }
                .buttonStyle(GlowButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 470)
        .background(Arcana.night)
        .preferredColorScheme(.dark)
    }

    private func row(_ symbol: String, _ color: Color, _ title: String, _ subtitle: String, _ items: [DiskItem]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title) · \(items.count)").font(.spell(13, .semibold)).foregroundStyle(Arcana.ink)
                Text(subtitle).font(.lore(13)).foregroundStyle(Arcana.faint)
            }
            Spacer()
            Text(items.reduce(0) { $0 + $1.size }.bytesText)
                .font(.spell(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(Arcana.ink)
        }
        .padding(12)
        .arcanePanel(radius: 12)
    }
}

/// Celebration after banishing, with the honest numbers.
struct ReclaimOverlay: View {
    @Environment(AppModel.self) private var model
    let report: CleanReport

    var body: some View {
        ZStack {
            Arcana.night.opacity(0.72).ignoresSafeArea()
            SparkBurst()
            VStack(spacing: 10) {
                FloatingMage(size: 150)
                Text("+" + report.deleted.bytesText)
                    .font(.spell(64, .bold))
                    .monospacedDigit()
                    .foregroundStyle(LinearGradient(colors: [Arcana.gold, Arcana.cyan], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Arcana.cyan.opacity(0.5), radius: 20)
                Text(report.deleted > 0 ? "returned to your disk" : "nothing erased this time")
                    .font(.lore(21).italic())
                    .foregroundStyle(Arcana.mist)
                if report.trashedCount > 0 {
                    Text("\(report.trashedCount) items (\(report.trashed.bytesText)) wait in the Trash. Empty it to free that space too.")
                        .font(.lore(14.5))
                        .foregroundStyle(Arcana.gold)
                        .padding(.top, 8)
                }
                if !report.failures.isEmpty {
                    Text("\(report.failures.count) items resisted: \(report.failures.prefix(3).map(\.name).joined(separator: ", "))")
                        .font(.lore(13.5))
                        .foregroundStyle(Arcana.ember)
                        .lineLimit(2)
                        .frame(maxWidth: 480)
                }
                HStack(spacing: 10) {
                    if report.trashedCount > 0 {
                        Button("Empty the Trash") { Task { await model.emptyTrashAfterReport() } }
                            .buttonStyle(GlowButtonStyle())
                    }
                    Button("Done") { withAnimation { model.lastReport = nil } }
                        .buttonStyle(GlowButtonStyle(prominent: report.trashedCount == 0))
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 14)
            }
            .multilineTextAlignment(.center)
        }
    }
}

/// The spell while files are leaving: motes of junk spiral up from the
/// mage's circle into the moon, with the real progress underneath.
struct BanishingOverlay: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var appeared = false

    var body: some View {
        let progress = model.progress
        GeometryReader { proxy in
            let size = proxy.size
            let moon = CGPoint(x: size.width / 2, y: size.height * 0.2)
            let circle = CGPoint(x: size.width / 2, y: size.height * 0.62)

            ZStack {
                Arcana.night.opacity(0.8).ignoresSafeArea()
                RadialGradient(colors: [Arcana.violet.opacity(0.28), .clear],
                               center: .init(x: 0.5, y: 0.2), startRadius: 10, endRadius: 420)

                TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSince(start)
                    Canvas { ctx, _ in
                        drawRunes(in: &ctx, at: circle, t: t)
                        drawMotes(in: &ctx, from: circle, to: moon, t: t)
                        drawMoon(in: &ctx, at: moon, t: t, fill: progress.fraction)
                    }
                }

                FloatingMage(size: 150)
                    .position(x: circle.x, y: circle.y - 70)
                    .scaleEffect(appeared ? 1 : 0.85)

                VStack(spacing: 10) {
                    Text("Sending your junk to the moon…")
                        .font(.spell(22, .bold))
                        .foregroundStyle(Arcana.ink)
                    Text(progress.current.isEmpty ? " " : progress.current)
                        .font(.lore(13.5))
                        .foregroundStyle(Arcana.mist)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 380)
                        .contentTransition(.opacity)
                    SpellProgress(fraction: progress.fraction)
                        .frame(width: 300, height: 6)
                        .padding(.top, 4)
                    HStack(spacing: 6) {
                        Text("\(progress.done) of \(progress.total)")
                        Text("·")
                        Text(progress.bytes.bytesText)
                    }
                    .font(.spell(13, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Arcana.faint)
                    .contentTransition(.numericText())
                }
                .position(x: size.width / 2, y: circle.y + 110)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .onAppear {
            start = .now
            withAnimation(.spring(duration: 0.6, bounce: 0.25)) { appeared = true }
        }
    }

    /// A rotating double ring of runes under the mage, seen at an angle.
    private func drawRunes(in ctx: inout GraphicsContext, at c: CGPoint, t: Double) {
        let pulse = 0.75 + 0.25 * sin(t * 3)
        for (radius, speed, dash) in [(120.0, 0.5, 14.0), (92.0, -0.8, 6.0)] {
            var ring = ctx
            ring.translateBy(x: c.x, y: c.y)
            ring.scaleBy(x: 1, y: 0.32)
            ring.rotate(by: .radians(t * speed))
            let path = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            ring.stroke(path, with: .color(Arcana.cyan.opacity(0.55 * pulse)),
                        style: StrokeStyle(lineWidth: 2, dash: [dash, dash * 0.7]))
        }
        var glow = ctx
        glow.addFilter(.blur(radius: 22))
        glow.fill(Path(ellipseIn: CGRect(x: c.x - 130, y: c.y - 36, width: 260, height: 72)),
                  with: .color(Arcana.violet.opacity(0.45 * pulse)))
    }

    /// Bits of junk rising in loose spirals and shrinking into the moon.
    private func drawMotes(in ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint, t: Double) {
        let colors = [Arcana.cyan, Arcana.violet, Arcana.gold]
        for i in 0..<46 {
            let seed = Double(i) * 0.618_034
            let speed = 0.32 + (seed.truncatingRemainder(dividingBy: 1)) * 0.22
            let p = (t * speed + seed).truncatingRemainder(dividingBy: 1)
            let eased = p * p * (3 - 2 * p)
            let spread = 120 * (1 - eased)
            let angle = seed * 9 + p * 7
            let x = a.x + (b.x - a.x) * eased + cos(angle) * spread
            let y = a.y + (b.y - a.y) * eased + sin(angle) * spread * 0.3
            let r = (1 - eased) * (i % 3 == 0 ? 6 : 4) + 1.5
            let alpha = min(1, p * 6) * (1 - pow(p, 6))
            let color = colors[i % colors.count]

            var halo = ctx
            halo.addFilter(.blur(radius: 6))
            halo.fill(Path(ellipseIn: CGRect(x: x - r * 2, y: y - r * 2, width: r * 4, height: r * 4)),
                      with: .color(color.opacity(0.5 * alpha)))
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            let shape = i % 4 == 0
                ? Path(roundedRect: rect, cornerRadius: r * 0.35)
                : Path(ellipseIn: rect)
            ctx.fill(shape, with: .color(color.opacity(alpha)))
        }
    }

    /// The moon swallows the junk and glows brighter as the work gets done.
    private func drawMoon(in ctx: inout GraphicsContext, at c: CGPoint, t: Double, fill: Double) {
        let r = 44.0
        let pulse = 0.85 + 0.15 * sin(t * 4.2)
        var glow = ctx
        glow.addFilter(.blur(radius: 30))
        let g = r * (1.5 + 0.5 * fill) * pulse
        glow.fill(Path(ellipseIn: CGRect(x: c.x - g, y: c.y - g, width: g * 2, height: g * 2)),
                  with: .color(Arcana.cyan.opacity(0.35 + 0.3 * fill)))
        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.fill(disc, with: .radialGradient(
            Gradient(colors: [.white, Color(red: 0.86, green: 0.88, blue: 1)]),
            center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), startRadius: 2, endRadius: r * 1.4))
        // A few soft craters.
        for (dx, dy, cr) in [(0.3, -0.2, 0.18), (-0.25, 0.3, 0.13), (0.1, 0.45, 0.09)] {
            let rect = CGRect(x: c.x + dx * r - cr * r, y: c.y + dy * r - cr * r, width: cr * r * 2, height: cr * r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.72, green: 0.74, blue: 0.9).opacity(0.55)))
        }
    }
}

/// A progress bar with light running through the filled part.
struct SpellProgress: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [Arcana.violet, Arcana.cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.height, w * fraction))
                    .overlay { ShimmerBar().opacity(0.6).clipShape(Capsule()) }
                    .shadow(color: Arcana.cyan.opacity(0.7), radius: 8)
            }
        }
    }
}
