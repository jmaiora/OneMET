import SwiftUI

@main
struct OneMETApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// Custom tab container (v2): Summary / Workouts / Plan / Profile, with a blurred
// floating TabBar, plus GlucoseDetail (from Summary) and WorkoutDetail (from
// Workouts) sliding overlays. Data from HealthDataStore; SampleData seeds previews.
struct RootView: View {
    @StateObject private var store = HealthDataStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var glucoseSource = GlucoseSourceStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .summary
    @State private var showGlucose = false
    @State private var openWorkout: WorkoutSession?
    private let accent = Theme.accent

    /// Display unit for every glucose value in the app (Profile ▸ Glucose Units).
    private var unit: GlucoseUnit { profileStore.profile.glucoseUnit }
    private let anim = Animation.easeInOut(duration: 0.25)

    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { tab },
            set: { newTab in
                withAnimation(anim) { showGlucose = false; openWorkout = nil }
                tab = newTab
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(active: tabBinding, accent: accent)
                .zIndex(5)

            if showGlucose {
                GlucoseDetailView(accent: accent, unit: unit) {
                    withAnimation(anim) { showGlucose = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }

            if let w = openWorkout {
                WorkoutDetailView(session: w, accent: accent, unit: unit) {
                    withAnimation(anim) { openWorkout = nil }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(3)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(accent)
        .environmentObject(store)
        .environmentObject(profileStore)
        .environmentObject(glucoseSource)
        .task {
            store.profile = profileStore.profile
            store.glucoseConfig = glucoseSource.config
            store.dexcomConfig = glucoseSource.dexcom
            await store.load()
        }
        .onChange(of: profileStore.profile) { newValue in
            store.profile = newValue
            Task { await store.refresh() }
        }
        .onChange(of: glucoseSource.config) { newConfig in
            store.glucoseConfig = newConfig
            store.startPolling()
            Task { await store.refresh() }
        }
        .onChange(of: glucoseSource.dexcom) { newValue in
            store.dexcomConfig = newValue
            store.startPolling()
            Task { await store.refresh() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await store.refresh() } }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch tab {
        case .summary:
            SummaryView(
                accent: accent,
                unit: unit,
                onOpenGlucose: { withAnimation(anim) { showGlucose = true } },
                onGoActivity: { tab = .workouts }
            )
        case .workouts:
            WorkoutsView(accent: accent, onOpenWorkout: { s in
                withAnimation(anim) { openWorkout = s }
            })
        case .plan:
            PlanView(accent: accent)
        case .profile:
            ProfileView(accent: accent)
        }
    }
}

#Preview {
    RootView()
}
