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
    @State private var tab: AppTab = .summary
    @State private var showGlucose = false
    @State private var openWorkout: WorkoutSession?
    @State private var mmol = false
    private let accent = Theme.accent
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
                .ignoresSafeArea(edges: .bottom)
                .zIndex(5)

            if showGlucose {
                GlucoseDetailView(accent: accent, mmol: mmol) {
                    withAnimation(anim) { showGlucose = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }

            if let w = openWorkout {
                WorkoutDetailView(session: w, accent: accent) {
                    withAnimation(anim) { openWorkout = nil }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(3)
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
