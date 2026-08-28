import SwiftUI

@main
struct OneMETApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// Custom tab container (v2): Summary / Workouts / Plan / Settings, with a blurred
// floating TabBar, plus GlucoseDetail (from Summary) and WorkoutDetail (from
// Workouts) sliding overlays. Data from HealthDataStore; SampleData seeds previews.
// On first launch the whole thing is covered by WelcomeView until language and units
// are chosen.
struct RootView: View {
    @StateObject private var store = HealthDataStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var glucoseSource = GlucoseSourceStore()
    @StateObject private var loc = LocalizationStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .summary
    @State private var showGlucose = false
    @State private var openWorkout: WorkoutSession?
    private let accent = Theme.accent

    /// Display unit for every glucose value in the app (Settings ▸ Glucose Units).
    private var unit: GlucoseUnit { profileStore.profile.glucoseUnit }
    private var lang: AppLanguage { loc.language }
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

            TabBar(active: tabBinding, accent: accent, lang: lang)
                .zIndex(5)

            if showGlucose {
                GlucoseDetailView(accent: accent, unit: unit, lang: lang) {
                    withAnimation(anim) { showGlucose = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }

            if let w = openWorkout {
                WorkoutDetailView(session: w, accent: accent, unit: unit, lang: lang) {
                    withAnimation(anim) { openWorkout = nil }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(3)
            }

            // First run: sits above everything, including the tab bar. Dismisses itself
            // by setting loc.hasOnboarded.
            if !loc.hasOnboarded {
                WelcomeView(loc: loc, profileStore: profileStore,
                            glucoseSource: glucoseSource, accent: accent)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(accent)
        .environment(\.locale, lang.locale)
        .environmentObject(store)
        .environmentObject(profileStore)
        .environmentObject(glucoseSource)
        .environmentObject(loc)
        .task {
            store.profile = profileStore.profile
            store.language = loc.language
            store.glucoseConfig = glucoseSource.config
            store.dexcomConfig = glucoseSource.dexcom
            store.libreConfig = glucoseSource.libre
            await store.load()
        }
        .onChange(of: profileStore.profile) { newValue in
            store.profile = newValue
            Task { await store.refresh() }
        }
        // Insights, week labels, sport names and diagnostics are all generated inside the
        // store, so a language change has to re-run a refresh to restate them.
        .onChange(of: loc.language) { newLang in
            store.language = newLang
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
        .onChange(of: glucoseSource.libre) { newValue in
            store.libreConfig = newValue
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
                lang: lang,
                onOpenGlucose: { withAnimation(anim) { showGlucose = true } },
                onGoActivity: { tab = .workouts }
            )
        case .workouts:
            WorkoutsView(accent: accent, lang: lang, onOpenWorkout: { s in
                withAnimation(anim) { openWorkout = s }
            })
        case .plan:
            PlanView(accent: accent, lang: lang)
        case .settings:
            SettingsView(accent: accent, lang: lang)
        }
    }
}

#Preview {
    RootView()
}
