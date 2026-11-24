import MageCore
import SwiftUI

/// Left column: the magic circle, the disk's numbers and why it is full.
struct OraclePanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            MagicCircle(segments: model.segments, scanning: model.isScanning) {
                circleCenter
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            stats
            if model.needsSight {
                SightBanner(compact: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            insights
            AuthorMark()
        }
        .padding(.horizontal, 24)
        .padding(.top, 44)
        .padding(.bottom, 20)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if let emblem = ArtLibrary.emblem {
                        Image(nsImage: emblem)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .shadow(color: Arcana.cyan.opacity(0.5), radius: 8)
                    } else {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(LinearGradient(colors: [Arcana.cyan, Arcana.violet], startPoint: .top, endPoint: .bottom))
                    }
                    Text("Space2Moon")
                        .font(.sigilTitle(25))
                        .foregroundStyle(Arcana.ink)
                }
                Text("Send your junk to the moon")
                    .font(.lore(14))
                    .foregroundStyle(Arcana.faint)
            }
            Spacer()
            Button {
                Task { await model.scan() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(GlowButtonStyle(prominent: false))
            .disabled(model.isScanning || model.banishing)
            .help("Divine again (⌘R)")
        }
    }

    @ViewBuilder
    private var circleCenter: some View {
        VStack(spacing: 2) {
            if let volume = model.volume {
                Text(volume.available.bytesText)
                    .font(.spell(28, .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()
                    .foregroundStyle(Arcana.ink)
                    .contentTransition(.numericText())
                Text("free of \(volume.total.bytesText)")
                    .font(.lore(13.5))
                    .foregroundStyle(Arcana.mist)
                if model.isScanning {
                    Scrying(label: "scrying \(model.scanning.count) realms…")
                        .font(.lore(13))
                        .padding(.top, 6)
                }
            } else {
                Scrying()
            }
        }
        .frame(maxWidth: 128)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("Truly used", model.volume?.used, Arcana.violet)
            stat("Purgeable", model.volume?.purgeable, Arcana.gold)
            stat("Free now", model.volume?.available, Arcana.cyan)
        }
    }

    private func stat(_ label: String, _ bytes: Int64?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6).shadow(color: color, radius: 3)
                Text(label.uppercased())
                    .font(.spell(9, .bold))
                    .tracking(0.8)
                    .foregroundStyle(Arcana.faint)
            }
            Text(bytes?.bytesText ?? "—")
                .font(.spell(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(Arcana.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .arcanePanel(radius: 12)
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Why your disk is full")
                    .font(.spell(17))
                    .foregroundStyle(Arcana.ink)
                Spacer()
                if let baseline = model.baseline {
                    Text("growth since \(baseline.date.formatted(.relative(presentation: .named)))")
                        .font(.lore(12.5))
                        .foregroundStyle(Arcana.faint)
                }
            }
            if model.insights.isEmpty {
                Scrying(label: model.isScanning ? "The oracle is reading your disk…" : "Nothing yet")
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(model.insights.enumerated()), id: \.element.id) { index, insight in
                        InsightRow(rank: index + 1, insight: insight)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct InsightRow: View {
    @Environment(AppModel.self) private var model
    let rank: Int
    let insight: Insight
    @State private var hovering = false

    private var color: Color {
        if insight.id == "purgeable" { return Arcana.gold }
        return insight.category.map(Arcana.color) ?? Arcana.mist
    }

    var body: some View {
        Button {
            if let category = insight.category { model.focus(category) }
        } label: {
            HStack(spacing: 10) {
                Text(rank, format: .number)
                    .font(.spell(13, .bold))
                    .foregroundStyle(color)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.spell(12.5, .semibold))
                        .foregroundStyle(Arcana.ink)
                        .lineLimit(1)
                    Text(insight.detail)
                        .font(.lore(12.5))
                        .foregroundStyle(Arcana.faint)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(insight.size.bytesText)
                        .font(.spell(12.5, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Arcana.ink)
                    if let growth = insight.growth, abs(growth) >= 200_000_000 {
                        Text((growth > 0 ? "+" : "−") + abs(growth).bytesText)
                            .font(.spell(10, .bold))
                            .foregroundStyle(growth > 0 ? Arcana.ember : Arcana.cyan)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(hovering ? 0.07 : 0.03)))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3, height: 22).shadow(color: color, radius: 4).offset(x: -1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// Explains Full Disk Access and opens the right settings pane.
struct SightBanner: View {
    @Environment(AppModel.self) private var model
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .foregroundStyle(Arcana.ember)
                Text("Grant the Sight")
                    .font(.spell(15))
                    .foregroundStyle(Arcana.ink)
            }
            Text("Without Full Disk Access, Mail, Messages, the Trash and iPhone backups stay hidden. Turn on Space2Moon in Privacy & Security › Full Disk Access, then reopen the app.")
                .font(.lore(13.5))
                .foregroundStyle(Arcana.mist)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Open settings") { model.openFullDiskAccess() }
                    .buttonStyle(GlowButtonStyle())
                if !compact {
                    Button("Show app in Finder") { model.revealApp() }
                        .buttonStyle(GlowButtonStyle(prominent: false))
                }
                Button("Reopen") { model.relaunch() }
                    .buttonStyle(GlowButtonStyle(prominent: false))
                    .help("macOS applies Full Disk Access after the app restarts")
            }
            .controlSize(.small)
        }
        .padding(14)
        .arcanePanel(radius: 14, glow: Arcana.ember, lit: true)
    }
}

/// Maker's mark at the foot of the spellbook.
struct AuthorMark: View {
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Arcana.gold.opacity(0.3)).frame(width: 18, height: 0.5)
            Text("Crafted by")
                .font(.lore(13).italic())
                .foregroundStyle(Arcana.faint)
            Link(destination: URL(string: "https://siri2moon.com")!) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill").font(.system(size: 10))
                    Text("siri2moon").font(.spell(12, .bold)).tracking(0.6)
                }
                .foregroundStyle(hovering ? Arcana.cyan : Arcana.gold)
                .shadow(color: (hovering ? Arcana.cyan : Arcana.gold).opacity(0.5), radius: hovering ? 6 : 2)
            }
            .onHover { hovering = $0 }
            .help("siri2moon.com")
            Rectangle().fill(Arcana.gold.opacity(0.3)).frame(width: 18, height: 0.5)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: hovering)
    }
}
