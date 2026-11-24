import MageCore
import SwiftUI

@main
struct Space2MoonApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1120, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Divine Again") { Task { await model.scan() } }
                    .keyboardShortcut("r")
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            ArcaneBackground().ignoresSafeArea()
            if let sanctum = ArtLibrary.sanctum {
                // An overlay on a flexible color keeps the filled image from
                // widening the layout beyond the window.
                Color.clear
                    .overlay {
                        Image(nsImage: sanctum)
                            .resizable()
                            .scaledToFill()
                    }
                    .blur(radius: 28)
                    .clipped()
                    .opacity(0.16)
                    .blendMode(.screen)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            HStack(spacing: 0) {
                OraclePanel()
                    .frame(width: 372)
                    .background(Arcana.night.opacity(0.45))
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Arcana.gold.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 1)
                ZStack {
                    if let id = model.focused {
                        CategoryDetail(id: id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)))
                    } else {
                        GrimoireGrid()
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) { BanishBar().padding(.bottom, 22) }
            }
            .ignoresSafeArea(edges: .top)

            if let report = model.lastReport {
                ReclaimOverlay(report: report)
                    .transition(.opacity)
            }

            if model.showSplash {
                SplashView { model.finishSplash() }
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
                    .zIndex(10)
            }
        }
        .task {
            if DevSnapshot.target != nil {
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    DevSnapshot.capture(suffix: "splash")
                }
            }
            if model.results.isEmpty { await model.scan() }
            if DevSnapshot.target != nil {
                model.focus(nil)
                try? await Task.sleep(for: .seconds(2))
                DevSnapshot.capture()
                if let first = CategoryID.allCases.max(by: { (model.results[$0]?.measured ?? 0) < (model.results[$1]?.measured ?? 0) }) {
                    model.focus(first)
                    try? await Task.sleep(for: .seconds(1.5))
                    DevSnapshot.capture(suffix: "detail")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.recheckAccess() }
        }
        .animation(.smooth, value: model.needsSight)
        .sheet(isPresented: $model.confirming) { ConfirmBanish() }
        .alert("Ritual", isPresented: Binding(
            get: { model.ritualMessage != nil }, set: { if !$0 { model.ritualMessage = nil } })
        ) {
            Button("OK") { model.ritualMessage = nil }
        } message: {
            Text(model.ritualMessage ?? "")
        }
    }
}
