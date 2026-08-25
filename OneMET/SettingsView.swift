import SwiftUI
import MessageUI

// SettingsView.swift — OneMET Settings tab (was Profile): identity, connected devices,
// glucose source, language, units and personal targets.

enum ProfileEditor: Int, Identifiable {
    case identity, language, glucose, units, met, carb, insulin, nightscout, dexcom
    var id: Int { rawValue }
}

struct SettingsView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var glucoseSource: GlucoseSourceStore
    @EnvironmentObject var loc: LocalizationStore
    var accent: Color
    var lang: AppLanguage = .en

    @State private var editor: ProfileEditor?
    @State private var exportFile: ExportFile?
    @State private var mailFile: ExportFile?

    var body: some View {
        let p = profileStore.profile

        ScreenScaffold(spacing: 18) {
            AppHeader(title: lang.t("settings.title"), date: lang.t("settings.account"),
                      initials: p.initials, accent: accent)

            // Identity row (tap to edit)
            Button { editor = .identity } label: {
                HStack(spacing: 14) {
                    Text(p.initials)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(accent)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.isConfigured ? p.name : lang.t("settings.setUpProfile"))
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(p.isConfigured ? Theme.ink : Theme.ink2)
                        Text(subtitle(p))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink2)
                    }
                    Spacer()
                    AppIconView(name: "chevron", color: Theme.ink3, size: 15)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Dots here are status, not decoration: green = we're receiving data from it,
            // grey = nothing detected.
            IOSList(header: lang.t("settings.devices")) {
                IOSListRow(title: lang.t("settings.cgm"),
                           detail: cgmDetail,
                           dot: cgmConnected ? Theme.green : Theme.ink3)
                IOSListRow(title: lang.t("settings.appleWatch"),
                           detail: watchDetected ? store.data.watchModel : lang.t("settings.notDetected"),
                           dot: watchDetected ? Theme.green : Theme.ink3, isLast: true)
            }

            IOSList(header: lang.t("settings.glucoseSource")) {
                IOSListRow(title: lang.t("settings.dexcom"),
                           detail: sourceDetail(active: glucoseSource.dexcom.isActive,
                                                configured: glucoseSource.dexcom.isConfigured),
                           dot: glucoseSource.dexcom.isActive ? Theme.green : Theme.ink3) { editor = .dexcom }
                IOSListRow(title: lang.t("settings.nightscout"),
                           detail: sourceDetail(active: glucoseSource.config.isActive,
                                                configured: glucoseSource.config.isConfigured),
                           dot: glucoseSource.config.isActive ? Theme.green : Theme.ink3,
                           isLast: true) { editor = .nightscout }
            }

            IOSList(header: lang.t("settings.general")) {
                IOSListRow(title: lang.t("settings.language"), detail: loc.language.nativeName,
                           dot: accent) { editor = .language }
                IOSListRow(title: lang.t("settings.glucoseUnits"), detail: p.glucoseUnit.rawValue,
                           dot: Theme.teal, isLast: true) { editor = .units }
            }

            IOSList(header: lang.t("settings.targets")) {
                IOSListRow(title: lang.t("settings.glucoseRange"), detail: p.glucoseRangeText, dot: Theme.green) { editor = .glucose }
                IOSListRow(title: lang.t("settings.metGoal"), detail: p.metGoalText, dot: Theme.ringMet) { editor = .met }
                IOSListRow(title: lang.t("settings.insulinDelivery"), detail: p.insulinDelivery.label(lang), dot: accent, isLast: true) { editor = .insulin }
            }

            IOSList(header: lang.t("settings.body")) {
                IOSListRow(title: lang.t("settings.weight"),
                           detail: p.weightKg == nil ? lang.t("common.notSet") : p.weightText,
                           dot: Theme.teal, isLast: true) { editor = .identity }
            }

            IOSList(header: lang.t("settings.data")) {
                IOSListRow(title: lang.t("settings.export"), dot: accent) { exportWorkouts() }
                IOSListRow(title: lang.t("settings.share"), dot: Theme.teal, isLast: true) { shareWithClinician() }
            }
        }
        .sheet(item: $editor) { which in
            switch which {
            case .identity:   EditIdentitySheet(store: profileStore, lang: lang)
            case .language:   EditLanguageSheet(loc: loc, lang: lang)
            case .glucose:    EditGlucoseRangeSheet(store: profileStore, lang: lang)
            case .units:      EditGlucoseUnitSheet(store: profileStore, lang: lang)
            case .met:        EditMetGoalSheet(store: profileStore, lang: lang)
            case .carb:       EditCarbRatioSheet(store: profileStore, lang: lang)
            case .insulin:    EditInsulinDeliverySheet(store: profileStore, lang: lang)
            case .nightscout: NightscoutSheet(store: glucoseSource, lang: lang)
            case .dexcom:     DexcomSheet(store: glucoseSource, lang: lang)
            }
        }
        .sheet(item: $exportFile) { file in
            ActivityView(activityItems: [file.url])
        }
        .sheet(item: $mailFile) { file in
            MailView(subject: lang.t("export.mailSubject"),
                     body: lang.t("export.mailBody"),
                     attachmentURL: file.url) { mailFile = nil }
        }
    }

    // MARK: - Derived labels

    private func subtitle(_ p: UserProfile) -> String {
        guard p.isConfigured else { return lang.t("settings.addDetails") }
        var s = p.diabetesType.label(lang)
        if let y = p.diagnosisYear { s += " · " + lang.t("settings.since", String(y)) }
        return s
    }

    private func sourceDetail(active: Bool, configured: Bool) -> String {
        if active { return lang.t("settings.onLive") }
        return configured ? lang.t("settings.configuredOff") : lang.t("common.notSet")
    }

    /// A CGM counts as connected when a remote source is live, or when Apple Health has
    /// actually handed us glucose readings — not merely because the app launched.
    private var cgmConnected: Bool {
        glucoseSource.dexcom.isActive || glucoseSource.config.isActive || store.data.hasGlucose
    }

    private var cgmDetail: String {
        if glucoseSource.dexcom.isActive { return lang.t("settings.dexcom") }
        if glucoseSource.config.isActive { return lang.t("settings.nightscout") }
        return store.data.hasGlucose ? lang.t("settings.appleHealth") : lang.t("settings.notLinked")
    }

    /// A watch is "detected" when a recent workout was recorded on one.
    private var watchDetected: Bool { !store.data.watchModel.isEmpty }

    // MARK: - Export

    /// Build a downloadable .xlsx of the workout history and present the share sheet.
    private func exportWorkouts() {
        let data = WorkoutExport.xlsx(history: store.data.workoutHistory)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneMET-Workouts.xlsx")
        if (try? data.write(to: url, options: .atomic)) != nil {
            exportFile = ExportFile(url: url)
        }
    }

    /// Email the health report to a clinician via the device's Mail account; if Mail
    /// isn't set up, fall back to the system share sheet (choose Gmail/Outlook/etc.).
    private func shareWithClinician() {
        let data = WorkoutExport.xlsx(history: store.data.workoutHistory)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneMET-Health-Report.xlsx")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        if MFMailComposeViewController.canSendMail() {
            mailFile = ExportFile(url: url)
        } else {
            exportFile = ExportFile(url: url)
        }
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); SettingsView(accent: Theme.accent)
        .environmentObject(HealthDataStore())
        .environmentObject(ProfileStore())
        .environmentObject(GlucoseSourceStore())
        .environmentObject(LocalizationStore())
    }
}
