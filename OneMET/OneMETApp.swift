import SwiftUI

@main
struct OneMETApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// Custom tab container matching the design handoff: a blurred floating TabBar
// with the active screen behind it and the GlucoseDetail overlay on top.
// Data comes from HealthDataStore (live HealthKit); SampleData is the preview seed.
struct RootView: View {
    @StateObject private var store = HealthDataStore()
    @StateObject private var profileStore = ProfileStore()
    @State private var tab: AppTab = .summary
    @State private var showGlucose = false
    @State private var mmol = false
    private let accent = Theme.accent
    private let anim = Animation.easeInOut(duration: 0.25)

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(active: $tab, accent: accent)
                .ignoresSafeArea(edges: .bottom)

            if showGlucose {
                GlucoseDetailView(accent: accent, mmol: mmol) {
                    withAnimation(anim) { showGlucose = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }
        }
        .tint(accent)
        .environmentObject(store)
        .environmentObject(profileStore)
        .task {
            store.profile = profileStore.profile
            await store.load()
        }
        .onChange(of: profileStore.profile) { newValue in
            store.profile = newValue
            Task { await store.refresh() }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch tab {
        case .summary:
            SummaryView(
                accent: accent,
                mmol: mmol,
                onOpenGlucose: { withAnimation(anim) { showGlucose = true } },
                onGoActivity: { tab = .activity },
                onGoTrends: { tab = .trends }
            )
        case .activity:
            ActivityView(accent: accent)
        case .trends:
            TrendsView(accent: accent, mmol: mmol)
        case .profile:
            ProfileView(accent: accent)
        }
    }
}

#Preview {
    RootView()
}
