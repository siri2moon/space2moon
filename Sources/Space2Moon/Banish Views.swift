import MageCore
import SwiftUI

/// Floating bar with the total chosen and the button that starts the cleaning.
struct BanishBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let bytes = model.chosenBytes
        if bytes > 0 || model.banishing {
            HStack(spacing: 16) {
                Image(systemName: "wand.and.stars")
                    .font(.lore(20))
                    .foregroundStyle(LinearGradient(colors: [Arcana.gold, Arcana.cyan], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 1) {
                    Text(bytes.bytesText)
                        .font(.spell(18, .bold))
                        .monospacedDigit()
                        .foregroundStyle(Arcana.ink)
                        .contentTransition(.numericText())
                    Text("\(model.chosen.count) items ready to banish")
                        .font(.lore(13))
                        .foregroundStyle(Arcana.mist)
                }
                Spacer(minLength: 20)
                Button {
                    model.confirming = true
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
            .frame(maxWidth: 560)
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
        let items = model.chosen
        let erased = items.filter { $0.method == .delete }
        let trashed = items.filter { $0.method == .trash }

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Sigil(symbol: "wand.and.stars", color: Arcana.violet, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cast the banishing?").font(.spell(22, .bold)).foregroundStyle(Arcana.ink)
                    Text(model.chosenBytes.bytesText + " will leave your disk")
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
