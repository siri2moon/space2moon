import MageCore
import SwiftUI

/// Right column, home state: one card per place space hides.
struct GrimoireGrid: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The Grimoire")
                            .font(.spell(30, .bold))
                            .foregroundStyle(Arcana.ink)
                        Text("Every realm where your disk space hides. Open one to see what's inside, choose, then banish.")
                            .font(.lore(15))
                            .foregroundStyle(Arcana.mist)
                    }
                    Spacer()
                    FloatingMage(size: 104)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 255, maximum: 360), spacing: 16)], spacing: 16) {
                    ForEach(CategoryID.allCases) { id in
                        CategoryCard(id: id)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.never)
    }
}

struct CategoryCard: View {
    @Environment(AppModel.self) private var model
    let id: CategoryID
    @State private var hovering = false

    var body: some View {
        let info = Grimoire.info(id)
        let color = Arcana.color(id)
        let result = model.results[id]
        let selected = model.selectedBytes(in: id)

        Button { model.focus(id) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Sigil(symbol: info.sigil, color: color)
                    Spacer()
                    VerdictChip(verdict: info.verdict)
                }
                Text(info.title)
                    .font(.spell(18))
                    .foregroundStyle(Arcana.ink)
                sizeLine(result)
                Text(info.lore)
                    .font(.lore(13.5))
                    .foregroundStyle(Arcana.faint)
                    .lineLimit(2, reservesSpace: true)
                HStack(spacing: 6) {
                    if selected > 0 {
                        Image(systemName: "wand.and.stars")
                        Text("\(selected.bytesText) chosen")
                    } else if let result, !result.items.isEmpty {
                        Text("\(result.items.count) \(result.items.count == 1 ? "item" : "items")")
                    }
                }
                .font(.spell(11, .semibold))
                .foregroundStyle(selected > 0 ? Arcana.cyan : Arcana.faint)
                .frame(height: 14)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .arcanePanel(radius: 18, glow: color, lit: hovering)
            .scaleEffect(hovering ? 1.012 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: hovering)
    }

    @ViewBuilder
    private func sizeLine(_ result: CategoryResult?) -> some View {
        Group {
            if model.scanning.contains(id) || result == nil {
                Scrying()
            } else if let result, result.accessDenied {
                Label("Needs Full Disk Access", systemImage: "lock.fill")
                    .font(.spell(13, .semibold))
                    .foregroundStyle(Arcana.ember)
            } else if let result, result.measured > 0 {
                Text(result.measured.bytesText)
                    .font(.spell(26, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Arcana.ink)
                    .contentTransition(.numericText())
            } else if let note = result?.note {
                Text(note)
                    .font(.lore(15, .semibold))
                    .foregroundStyle(Arcana.gold)
                    .lineLimit(1)
            } else {
                Text("Pure ✦")
                    .font(.lore(21).italic())
                    .foregroundStyle(Arcana.faint)
            }
        }
        .frame(height: 32, alignment: .leading)
    }
}

/// Right column, focused state: the items of one category.
struct CategoryDetail: View {
    @Environment(AppModel.self) private var model
    let id: CategoryID
    @State private var pendingRitual: Ritual?

    var body: some View {
        let info = Grimoire.info(id)
        let color = Arcana.color(id)
        let result = model.results[id]
        let items = result?.items ?? []
        let largest = max(1, items.map(\.size).max() ?? 1)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button { model.focus(nil) } label: {
                    Label("Grimoire", systemImage: "chevron.left")
                }
                .buttonStyle(GlowButtonStyle(prominent: false))
                .keyboardShortcut(.cancelAction)

                HStack(alignment: .top, spacing: 18) {
                    Sigil(symbol: info.sigil, color: color, size: 64)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text(info.title).font(.spell(30, .bold)).foregroundStyle(Arcana.ink)
                            VerdictChip(verdict: info.verdict)
                        }
                        Text(info.lore)
                            .font(.lore(15))
                            .foregroundStyle(Arcana.mist)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = result?.note {
                            Text(note).font(.lore(14, .semibold)).foregroundStyle(Arcana.gold)
                        }
                    }
                    Spacer(minLength: 0)
                    if let result, result.measured > 0 {
                        Text(result.measured.bytesText)
                            .font(.spell(30, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(color)
                            .shadow(color: color.opacity(0.5), radius: 10)
                    }
                }

                if result?.accessDenied == true {
                    SightBanner()
                }

                HStack(spacing: 10) {
                    if let ritual = info.ritual {
                        Button {
                            if ritual.warning != nil { pendingRitual = ritual } else { Task { await model.perform(ritual, for: id) } }
                        } label: {
                            HStack(spacing: 6) {
                                if model.ritualRunning == id { ProgressView().controlSize(.small) } else { Image(systemName: "wand.and.rays") }
                                Text(ritual.label)
                            }
                        }
                        .buttonStyle(GlowButtonStyle())
                        .disabled(model.ritualRunning != nil)
                    }
                    Spacer()
                    if items.contains(where: { $0.method != .none }) {
                        Button("Choose all") { model.selectAll(id, true) }
                            .buttonStyle(GlowButtonStyle(prominent: false))
                        Button("Choose none") { model.selectAll(id, false) }
                            .buttonStyle(GlowButtonStyle(prominent: false))
                    }
                }

                if model.scanning.contains(id) {
                    Scrying().padding(.top, 20)
                } else if items.isEmpty, result?.accessDenied != true {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles").font(.lore(30)).foregroundStyle(Arcana.gold)
                        Text("Nothing hides here.").font(.lore(21).italic()).foregroundStyle(Arcana.mist)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { item in
                            ItemRow(item: item, color: color, fraction: Double(item.size) / Double(largest))
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 44)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.never)
        .confirmationDialog(
            pendingRitual?.label ?? "", isPresented: Binding(get: { pendingRitual != nil }, set: { if !$0 { pendingRitual = nil } }),
            titleVisibility: .visible
        ) {
            Button("Cast the ritual", role: .destructive) {
                if let ritual = pendingRitual { Task { await model.perform(ritual, for: id) } }
                pendingRitual = nil
            }
            Button("Cancel", role: .cancel) { pendingRitual = nil }
        } message: {
            Text(pendingRitual?.warning ?? "")
        }
    }
}

struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: DiskItem
    let color: Color
    let fraction: Double
    @State private var hovering = false

    var body: some View {
        let chosen = model.selection.contains(item.url)
        HStack(spacing: 12) {
            RuneCheck(on: chosen, color: color, disabled: item.method == .none)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.lore(15, .semibold))
                        .foregroundStyle(Arcana.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    methodTag
                }
                HStack(spacing: 8) {
                    if let detail = item.detail {
                        Text(detail).lineLimit(1).truncationMode(.middle)
                    }
                    if let date = item.modified {
                        Text(date.formatted(.relative(presentation: .named)))
                    }
                }
                .font(.lore(13))
                .foregroundStyle(Arcana.faint)
                GeometryReader { proxy in
                    Capsule().fill(color.opacity(0.65))
                        .frame(width: max(2, proxy.size.width * fraction))
                        .shadow(color: color.opacity(0.6), radius: 3)
                }
                .frame(height: 2.5)
            }
            Spacer(minLength: 10)
            if item.size > 0 {
                Text(item.size.bytesText)
                    .font(.spell(13, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(chosen ? Arcana.ink : Arcana.mist)
            }
            if item.url.isFileURL {
                Button { model.reveal(item) } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Arcana.faint)
                    .opacity(hovering ? 1 : 0)
                    .help("Show in Finder")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(chosen ? 0.07 : hovering ? 0.05 : 0.025)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(chosen ? color.opacity(0.35) : .clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(item) }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.spring(duration: 0.25), value: chosen)
    }

    @ViewBuilder
    private var methodTag: some View {
        switch item.method {
        case .delete: EmptyView()
        case .trash:
            Text("TO TRASH").font(.spell(8.5, .bold)).tracking(0.8).foregroundStyle(Arcana.gold.opacity(0.85))
        case .none:
            Text("INFO").font(.spell(8.5, .bold)).tracking(0.8).foregroundStyle(Arcana.faint)
        }
    }
}

struct RuneCheck: View {
    let on: Bool
    let color: Color
    var disabled = false

    var body: some View {
        ZStack {
            if disabled {
                Image(systemName: "info.circle").foregroundStyle(Arcana.faint)
            } else {
                Circle().strokeBorder(on ? color : Arcana.faint, lineWidth: 1.2)
                if on {
                    Circle().fill(color).padding(4).shadow(color: color, radius: 5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: 18, height: 18)
    }
}
