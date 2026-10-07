import SwiftUI
import MessageUI
import StoreKit

// SettingsView.swift — OneMET Settings tab.
//
// The root stays short: who you are, what's connected, where glucose comes from, and two
// doors — Profile (language, units, targets) and Help & FAQ. Both push in as overlays
// rather than sheets, so the per-setting editors underneath can still be sheets.

enum ProfileEditor: Int, Identifiable {
    case identity, language, glucose, units, met, carb, insulin, interval, risk, nightscout, dexcom, libre
    var id: Int { rawValue }
}

struct SettingsView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var glucoseSource: GlucoseSourceStore
    @EnvironmentObject var loc: LocalizationStore
    @EnvironmentObject var subs: SubscriptionStore
    var accent: Color
    var lang: AppLanguage = .en
    /// Deep link from the Summary's closed-loop note: open Help at the closed-loop page.
    @Binding var openAidHelp: Bool

    @State private var editor: ProfileEditor?
    @State private var helpStartsOnAid = false
    @State private var exportFile: ExportFile?
    @State private var mailFile: ExportFile?
    @State private var showProfile = false
    @State private var showHelp = false
    @State private var showManageSubs = false

    private let anim = Animation.easeInOut(duration: 0.25)

    var body: some View {
        let p = profileStore.profile

        ZStack {
            ScreenScaffold(spacing: 18) {
                AppHeader(title: lang.t("settings.title"), date: lang.t("settings.account"),
                          initials: p.initials, accent: accent)

                // Identity card — the way in to everything personal.
                Button { withAnimation(anim) { showProfile = true } } label: {
                    HStack(spacing: 14) {
                        Text(p.initials)
                            .font(.app(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(accent)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.isConfigured ? p.name : lang.t("settings.setUpProfile"))
                                .font(.app(size: 21, weight: .bold))
                                .foregroundStyle(p.isConfigured ? Theme.ink : Theme.ink2)
                            Text(subtitle(p))
                                .font(.app(size: 14))
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

                // Dots here are status, not decoration: green = we're receiving data from
                // it, grey = nothing detected.
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
                    IOSListRow(title: lang.t("settings.libre"),
                               detail: sourceDetail(active: glucoseSource.libre.isActive,
                                                    configured: glucoseSource.libre.isConfigured),
                               dot: glucoseSource.libre.isActive ? Theme.green : Theme.ink3) { editor = .libre }
                    IOSListRow(title: lang.t("settings.nightscout"),
                               detail: sourceDetail(active: glucoseSource.config.isActive,
                                                    configured: glucoseSource.config.isConfigured),
                               dot: glucoseSource.config.isActive ? Theme.green : Theme.ink3,
                               isLast: true) { editor = .nightscout }
                }

                IOSList(header: lang.t("settings.data")) {
                    IOSListRow(title: lang.t("settings.export"), dot: accent) { exportWorkouts() }
                    IOSListRow(title: lang.t("settings.share"), dot: Theme.teal, isLast: true) { shareWithClinician() }
                }

                // Subscribers manage or cancel through Apple's own sheet; everyone else
                // gets the paywall. Restore is here as well as on the paywall, as App
                // Review expects it to be findable without starting a purchase.
                IOSList(header: lang.t("pro.title")) {
                    IOSListRow(title: lang.t("settings.subscription"), detail: proDetail,
                               dot: subs.isPro ? Theme.green : Theme.ink3) {
                        if subs.isPro { showManageSubs = true } else { subs.requirePro {} }
                    }
                    IOSListRow(title: lang.t("pro.restore"), dot: accent, isLast: true) {
                        Task { await subs.restore() }
                    }
                }

                // No Profile row here — the identity card at the top is already the way in.
                IOSList(header: lang.t("settings.more")) {
                    IOSListRow(title: lang.t("settings.help"), detail: lang.t("settings.helpSub"),
                               dot: Theme.violet, isLast: true) { withAnimation(anim) { showHelp = true } }
                }
            }

            if showProfile {
                ProfileMenuView(accent: accent, lang: lang, editor: $editor) {
                    withAnimation(anim) { showProfile = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }

            if showHelp {
                HelpView(accent: accent, lang: lang, unit: p.glucoseUnit,
                         startOnAid: helpStartsOnAid) {
                    withAnimation(anim) { showHelp = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(3)
            }
        }
        .onAppear {
            guard openAidHelp else { return }
            openAidHelp = false
            helpStartsOnAid = true
            showHelp = true
        }
        .onChange(of: showHelp) { open in
            if !open { helpStartsOnAid = false }
        }
        .sheet(item: $editor) { which in
            switch which {
            case .identity:   EditIdentitySheet(store: profileStore, lang: lang,
                                                healthMassKg: store.healthMassKg)
            case .language:   EditLanguageSheet(loc: loc, lang: lang)
            case .glucose:    EditGlucoseRangeSheet(store: profileStore, lang: lang)
            case .units:      EditGlucoseUnitSheet(store: profileStore, lang: lang)
            case .met:        EditMetGoalSheet(store: profileStore, lang: lang)
            case .carb:       EditCarbRatioSheet(store: profileStore, lang: lang)
            case .insulin:    EditInsulinDeliverySheet(store: profileStore, lang: lang)
            case .interval:   EditCarbIntervalSheet(store: profileStore, lang: lang)
            case .risk:       EditRiskGroupSheet(store: profileStore, lang: lang,
                                                 sessionsPerWeek: store.data.longSessionsPerWeek,
                                                 tbrPct: store.data.tbr14)
            case .nightscout: NightscoutSheet(store: glucoseSource, lang: lang)
            case .dexcom:     DexcomSheet(store: glucoseSource, lang: lang)
            case .libre:      LibreLinkUpSheet(store: glucoseSource, lang: lang)
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubs)
        // Restore's outcome. The paywall shows its own inline, so stay quiet while it's up.
        .alert(subs.noticeKey.map { lang.t($0) } ?? "",
               isPresented: Binding(get: { subs.noticeKey != nil && !subs.paywallShown },
                                    set: { if !$0 { subs.noticeKey = nil } })) {
            Button(lang.t("pro.ok"), role: .cancel) {}
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

    /// "Yearly · renews 12 Oct 2027", "Monthly · ends …", or "Not subscribed".
    private var proDetail: String {
        guard subs.isPro else { return lang.t("settings.proInactive") }
        let plan: String
        switch subs.activeProductId {
        case ProProduct.yearly:  plan = lang.t("pro.yearly")
        case ProProduct.monthly: plan = lang.t("pro.monthly")
        default:                 return lang.t("settings.proActive")
        }
        guard let end = subs.expirationDate else { return plan }
        let date = end.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(lang.locale))
        return lang.t(subs.willRenew ? "settings.proRenews" : "settings.proEnds", plan, date)
    }

    private func sourceDetail(active: Bool, configured: Bool) -> String {
        if active { return lang.t("settings.onLive") }
        return configured ? lang.t("settings.configuredOff") : lang.t("common.notSet")
    }

    /// A CGM counts as connected when a remote source is live, or when Apple Health has
    /// actually handed us glucose readings — not merely because the app launched.
    private var cgmConnected: Bool {
        glucoseSource.dexcom.isActive || glucoseSource.libre.isActive
            || glucoseSource.config.isActive || store.data.hasGlucose
    }

    private var cgmDetail: String {
        if glucoseSource.dexcom.isActive { return lang.t("settings.dexcom") }
        if glucoseSource.libre.isActive { return lang.t("settings.libre") }
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

// MARK: - Profile submenu

/// Everything personal, one level down from Settings: who you are, how the app talks to
/// you, and the targets the rings and the Plan tab work against.
struct ProfileMenuView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var loc: LocalizationStore
    @EnvironmentObject var store: HealthDataStore
    var accent: Color
    var lang: AppLanguage = .en
    @Binding var editor: ProfileEditor?
    var onBack: () -> Void

    var body: some View {
        let p = profileStore.profile

        ScreenScaffold(spacing: 18) {
            BackBar(title: lang.t("settings.title"), accent: accent, action: onBack)

            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("settings.account").uppercased())
                    .font(.app(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                Text(lang.t("settings.profile"))
                    .font(.app(size: 32, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            IOSList(header: lang.t("edit.identity")) {
                IOSListRow(title: lang.t("edit.profile"),
                           detail: p.isConfigured ? p.name : lang.t("common.notSet"),
                           dot: accent) { editor = .identity }
                // The override if set, else whatever Health last reported. "Not set" is
                // now only true when Health has nothing either — no permission, or no
                // weight ever recorded.
                IOSListRow(title: lang.t("settings.weight"),
                           detail: weightDetail(p, lang: lang),
                           dot: Theme.teal, isLast: true) { editor = .identity }
            }

            IOSList(header: lang.t("settings.general")) {
                IOSListRow(title: lang.t("settings.language"), detail: loc.language.nativeName,
                           dot: accent) { editor = .language }
                IOSListRow(title: lang.t("settings.glucoseUnits"), detail: p.glucoseUnit.rawValue,
                           dot: Theme.teal, isLast: true) { editor = .units }
            }

            IOSList(header: lang.t("settings.targets")) {
                IOSListRow(title: lang.t("settings.glucoseRange"), detail: p.glucoseRangeText,
                           dot: Theme.green) { editor = .glucose }
                IOSListRow(title: lang.t("settings.metGoal"), detail: p.metGoalText,
                           dot: Theme.ringMet) { editor = .met }
                IOSListRow(title: lang.t("settings.insulinDelivery"), detail: p.insulinDelivery.label(lang),
                           dot: accent) { editor = .insulin }
                IOSListRow(title: lang.t("settings.carbInterval"), detail: p.carbIntervalText,
                           dot: Theme.amber) { editor = .interval }
                IOSListRow(title: lang.t("settings.riskGroup"), detail: riskDetail(p, lang: lang),
                           dot: Theme.red, isLast: true) { editor = .risk }
            }
        }
    }

    /// "Automatic · Moderate risk", or just the pinned group.
    private func riskDetail(_ p: UserProfile, lang: AppLanguage) -> String {
        let group = store.data.risk.group.label(lang)
        return p.riskGroupSetting == .automatic ? "\(lang.t("risk.auto")) · \(group)" : group
    }

    /// Manual override first, then Health's reading, then an honest "not set".
    private func weightDetail(_ p: UserProfile, lang: AppLanguage) -> String {
        if p.weightKg != nil { return p.weightText }
        if let hk = store.healthMassKg { return String(format: "%.1f kg", hk) }
        return lang.t("common.notSet")
    }
}

// MARK: - Help & FAQ

/// The long-form guidance that used to sit in the Plan tab's "Good to know" card, plus
/// the questions that card kept raising: what a MET·minute is, how the insight decides
/// whether to suggest carbs, and which source each number came from.
struct HelpView: View {
    var accent: Color
    var lang: AppLanguage = .en
    var unit: GlucoseUnit = .mgdl
    /// Arrived from the Summary's closed-loop note: open on the closed-loop page, with
    /// Back leading to the rest of Help.
    var startOnAid = false
    var onBack: () -> Void

    @State private var showAid = false
    private let anim = Animation.easeInOut(duration: 0.25)

    var body: some View {
        ZStack {
            list
                .onAppear { if startOnAid { showAid = true } }

            if showAid {
                AidHelpView(accent: accent, lang: lang) {
                    withAnimation(anim) { showAid = false }
                }
                .background(Theme.bg.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
    }

    private var list: some View {
        ScreenScaffold(spacing: 14) {
            BackBar(title: lang.t("settings.title"), accent: accent, action: onBack)

            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("help.subtitle").uppercased())
                    .font(.app(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .tracking(0.2)
                Text(lang.t("help.title"))
                    .font(.app(size: 32, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Closed loop first: it decides whether the rest of the plan applies at all.
            // One sentence here; the reasons are one tap further in.
            Button { withAnimation(anim) { showAid = true } } label: {
                Card {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.app(size: 15))
                            .foregroundStyle(Theme.ringMet)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lang.t("help.aidTitle"))
                                .font(.app(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(lang.t("help.aidBody"))
                                .font(Theme.articleFont)
                                .lineSpacing(Theme.articleLineSpacing)
                                .foregroundStyle(Theme.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(lang.t("help.aidMore"))
                                .font(.app(size: 15, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "info.circle")
                            .font(.app(size: 20))
                            .foregroundStyle(accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            entry("checkmark.seal.fill", Theme.green, lang.t("help.duringTitle"),
                  lang.t("philosophy", unit.range(140, 200), unit.range(100, 140)))
            entry("chart.line.uptrend.xyaxis", accent, lang.t("help.learnTitle"),
                  lang.t("learn"))
            entry("bolt.fill", Theme.ringMet, lang.t("help.metTitle"),
                  lang.t("help.metBody"))
            entry("waveform.path.ecg", Theme.violet, lang.t("help.insightTitle"),
                  lang.t("help.insightBody", unit.amount(126), unit.amount(60), unit.amount(190)))
            entry("clock.fill", Theme.ringMet, lang.t("help.intervalTitle"),
                  lang.t("help.intervalBody"))
            entry("dumbbell.fill", Theme.violet, lang.t("help.anaerobicTitle"),
                  lang.t("help.anaerobicBody", unit.amount(18), unit.amount(14), unit.amount(9)))
            entry("list.bullet.clipboard", accent, lang.t("help.planTitle"),
                  lang.t("help.planBody"))
            entry("shield.lefthalf.filled", Theme.red, lang.t("help.riskTitle"),
                  lang.t("help.riskBody", unit.amount(126), unit.range(126, 180),
                         unit.amount(145), unit.range(145, 198),
                         unit.amount(162), unit.range(162, 216), unit.amount(70)))
            entry("person.fill.checkmark", Theme.amber, lang.t("help.scopeTitle"),
                  lang.t("help.scopeBody"))
            entry("drop.fill", Theme.teal, lang.t("help.sourcesTitle"),
                  lang.t("help.sourcesBody"))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.app(size: 14.5))
                        .foregroundStyle(Theme.amber)
                    Text(lang.t("plan.disclaimer"))
                        .font(Theme.noteFont.weight(.medium))
                        .lineSpacing(Theme.noteLineSpacing)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(lang.t("plan.sources").trimmingCharacters(in: .whitespaces))
                    .font(Theme.fineFont)
                    .foregroundStyle(Theme.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.amber.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func entry(_ icon: String, _ color: Color, _ title: String, _ body: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.app(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.app(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(body)
                        .font(Theme.articleFont)
                        .lineSpacing(Theme.articleLineSpacing)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Closed-loop detail

/// Why the fuel plan asks closed-loop users for manual mode: the sport mode ignores
/// intensity, so carbs can't be quantified, and the algorithm can't learn from the session.
struct AidHelpView: View {
    var accent: Color
    var lang: AppLanguage = .en
    var onBack: () -> Void

    var body: some View {
        ScreenScaffold(spacing: 14) {
            BackBar(title: lang.t("help.title"), accent: accent, action: onBack)

            Text(lang.t("help.aidDetailTitle"))
                .font(.app(size: 32, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            section("speedometer", Theme.ringMet, lang.t("help.aidSportTitle"), lang.t("help.aidSportBody"))
            section("brain.head.profile", Theme.violet, lang.t("help.aidLearnTitle"), lang.t("help.aidLearnBody"))
            section("hand.raised.fill", accent, lang.t("help.aidManualTitle"), lang.t("help.aidManualBody"))
        }
    }

    private func section(_ icon: String, _ color: Color, _ title: String, _ body: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.app(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.app(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(body)
                        .font(Theme.articleFont)
                        .lineSpacing(Theme.articleLineSpacing)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Shared back bar

struct BackBar: View {
    var title: String
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.app(size: 17, weight: .semibold))
                Text(title).font(.app(size: 17))
            }
            .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); SettingsView(accent: Theme.accent, openAidHelp: .constant(false))
        .environmentObject(HealthDataStore())
        .environmentObject(ProfileStore())
        .environmentObject(GlucoseSourceStore())
        .environmentObject(LocalizationStore())
        .environmentObject(SubscriptionStore())
    }
}
