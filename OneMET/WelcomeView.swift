import SwiftUI

// WelcomeView.swift — first-run setup, as three steps.
//
//   1. About you       — name, weight, diabetes type, then language and units. One scroll.
//   2. Apple Health    — explained before iOS throws its permission sheet up, so the
//                        request isn't the first thing you see with no context.
//   3. Glucose source  — optional; Apple Health covers it if you skip.
//
// The language picker sits below the personal questions rather than above them, which
// means the first screen may open in the wrong language. That's fine: it applies live, so
// choosing it re-renders the fields above in place — and it keeps the opening question a
// human one rather than a settings chore.
//
// Nothing here is mandatory, and every answer is editable afterwards in Settings ▸
// Profile. The profile is written once, at the end, so backing out midway leaves nothing
// half-saved. The diagnosis year isn't asked here at all — it's a detail, and it lives in
// the Settings identity sheet.

struct WelcomeView: View {
    @ObservedObject var loc: LocalizationStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var glucoseSource: GlucoseSourceStore
    @EnvironmentObject var store: HealthDataStore
    var accent: Color = Theme.accent

    @State private var step = 0
    private let stepCount = 3

    // Held locally and committed on the last step, except language, which applies
    // immediately so you can watch the screen change into the language you chose.
    @State private var unit: GlucoseUnit = .mgdl
    @State private var name = ""
    @State private var weightText = ""
    @State private var type: DiabetesType = .type1
    @State private var healthAsked = false
    @State private var seeded = false
    @State private var editing: WelcomeSource?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name, weight }

    var body: some View {
        let lang = loc.language

        VStack(spacing: 0) {
            header(lang)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case 0: youStep(lang)
                    case 1: healthStep(lang)
                    default: sourcesStep(lang)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }

            footer(lang)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: seed)
        .sheet(item: $editing) { which in
            switch which {
            case .nightscout: NightscoutSheet(store: glucoseSource, lang: loc.language)
            case .dexcom:     DexcomSheet(store: glucoseSource, lang: loc.language)
            case .libre:      LibreLinkUpSheet(store: glucoseSource, lang: loc.language)
            }
        }
    }

    /// Pre-fill from whatever is already saved, so re-running setup isn't a blank slate.
    ///
    /// Runs exactly once. `onAppear` fires again when a glucose-source sheet is dismissed,
    /// and re-seeding there would reset the name and weight to the still-empty saved
    /// profile — silently throwing away everything typed on step 1.
    private func seed() {
        guard !seeded else { return }
        seeded = true
        let p = profileStore.profile
        unit = p.glucoseUnit
        name = p.name
        weightText = p.weightKg.map { String(format: "%.1f", $0) } ?? ""
        type = p.diabetesType
    }

    // MARK: - Chrome

    private func header(_ lang: AppLanguage) -> some View {
        VStack(spacing: 12) {
            HStack {
                if step > 0 {
                    Button { focus = nil; withAnimation(.easeInOut(duration: 0.22)) { step -= 1 } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                            Text(lang.t("welcome.back")).font(.system(size: 16))
                        }
                        .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(lang.t("welcome.step", String(step + 1), String(stepCount)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }

            // Progress dots, matching the sport deck's pager style.
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? accent : Theme.ink3.opacity(0.4))
                        .frame(width: i == step ? 18 : 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func footer(_ lang: AppLanguage) -> some View {
        VStack(spacing: 10) {
            Button {
                focus = nil
                if step < stepCount - 1 {
                    withAnimation(.easeInOut(duration: 0.22)) { step += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(lang.t(step < stepCount - 1 ? "welcome.next" : "welcome.start"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .shadow(color: accent.opacity(0.3), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            Text(lang.t("welcome.disclaimer"))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(Theme.bg)
    }

    /// Writes everything at once, then dismisses — RootView shows this screen only while
    /// `hasOnboarded` is false.
    private func finish() {
        var p = profileStore.profile
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.glucoseUnit = unit
        p.diabetesType = type
        // Setup doesn't ask for a year; only clear a stored one if the type can't have a
        // diagnosis at all. Otherwise leave whatever Settings holds.
        if !type.hasDiagnosis { p.diagnosisYear = nil }
        // Accept both "72.5" and "72,5" — the decimal pad gives whichever the locale uses.
        let cleaned = weightText.replacingOccurrences(of: ",", with: ".")
        p.weightKg = cleaned.isEmpty ? nil : Double(cleaned)
        profileStore.profile = p

        // Push straight into the data store as well, rather than waiting for RootView's
        // onChange to relay it. Flipping hasOnboarded below triggers load(), and the order
        // in which two onChange handlers fire within one update isn't guaranteed — if the
        // hasOnboarded one wins, that first load would compute MET·minutes against the
        // default 70 kg instead of the weight just entered.
        store.profile = p
        store.language = loc.language

        withAnimation(.easeInOut(duration: 0.3)) { loc.hasOnboarded = true }
    }

    // MARK: - Step 1 · about you, then language and units

    @ViewBuilder
    private func youStep(_ lang: AppLanguage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent)
                AppIconView(name: "drop", color: .white, size: 30)
            }
            .frame(width: 62, height: 62)
            .padding(.bottom, 4)

            Text(lang.t("welcome.title"))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(lang.t("welcome.subtitle"))
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }

        fieldBlock(title: lang.t("welcome.namePrompt")) {
            TextField(lang.t("welcome.namePlace"), text: $name)
                .textInputAutocapitalization(.words)
                .font(.system(size: 17))
                .focused($focus, equals: .name)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }

        fieldBlock(title: lang.t("welcome.weightPrompt"), footer: lang.t("welcome.weightNote")) {
            HStack {
                TextField("—", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17))
                    .focused($focus, equals: .weight)
                Text("kg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }

        choiceBlock(title: lang.t("welcome.typePrompt"), footer: lang.t("welcome.aboutLead")) {
            ForEach(DiabetesType.onboardingChoices) { t in
                choiceRow(title: t.label(lang),
                          selected: type == t,
                          isLast: t == DiabetesType.onboardingChoices.last) {
                    withAnimation(.easeInOut(duration: 0.18)) { type = t }
                }
            }
        }

        // Language sits under the personal questions rather than over them. It applies
        // live, so tapping it re-renders everything above in the chosen language.
        choiceBlock(title: lang.t("welcome.language")) {
            ForEach(AppLanguage.allCases) { l in
                choiceRow(title: l.nativeName,
                          selected: loc.language == l,
                          isLast: l == AppLanguage.allCases.last) {
                    withAnimation(.easeInOut(duration: 0.18)) { loc.language = l }
                }
            }
        }

        choiceBlock(title: lang.t("welcome.units"), footer: lang.t("welcome.unitsNote")) {
            ForEach(GlucoseUnit.allCases) { u in
                choiceRow(title: u.longName,
                          selected: unit == u,
                          isLast: u == GlucoseUnit.allCases.last) {
                    withAnimation(.easeInOut(duration: 0.18)) { unit = u }
                }
            }
        }
    }

    // MARK: - Step 2 · Apple Health

    @ViewBuilder
    private func healthStep(_ lang: AppLanguage) -> some View {
        stepHeading(lang.t("welcome.healthTitle"), lang.t("welcome.healthLead"))

        VStack(alignment: .leading, spacing: 14) {
            ForEach(healthItems(lang)) { item in
                HStack(spacing: 11) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(accent)
                        .frame(width: 24)
                    Text(item.label)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

        if HealthKitService.isAvailable {
            Button {
                healthAsked = true
                // iOS shows its own sheet; it only ever appears once per install, so this
                // is deliberately fired from a button rather than on view load.
                Task { await store.reRequestHealthAccess() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: healthAsked ? "checkmark" : "heart.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(lang.t(healthAsked ? "welcome.healthDone" : "welcome.healthAllow"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(healthAsked ? Theme.green : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(healthAsked ? Theme.green.opacity(0.15) : Theme.red,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            Text(lang.t("welcome.healthSkip"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink3)
        }

        Text(lang.t("welcome.healthNote"))
            .font(.system(size: 12))
            .foregroundStyle(Theme.ink3)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// What OneMET will read, listed before iOS asks. A named type rather than a tuple so
    /// ForEach has a real Identifiable to key on.
    private struct HealthItem: Identifiable {
        let id: String
        let label: String
        let symbol: String
    }

    private func healthItems(_ lang: AppLanguage) -> [HealthItem] {
        [HealthItem(id: "workouts", label: lang.t("workouts.title"), symbol: "figure.run"),
         HealthItem(id: "activity", label: lang.t("summary.activity"), symbol: "flame.fill"),
         HealthItem(id: "heart", label: lang.t("workouts.avgHr"), symbol: "heart.fill"),
         HealthItem(id: "glucose", label: lang.t("summary.glucose"), symbol: "drop.fill")]
    }

    // MARK: - Step 3 · glucose source

    @ViewBuilder
    private func sourcesStep(_ lang: AppLanguage) -> some View {
        stepHeading(lang.t("welcome.sources"), lang.t("welcome.sourcesNote"))

        VStack(spacing: 10) {
            ForEach(WelcomeSource.allCases) { sourceRow($0, lang: lang) }
        }
    }

    /// The three services OneMET can read glucose from, in the order they're offered.
    enum WelcomeSource: Int, Identifiable, CaseIterable {
        case nightscout, dexcom, libre
        var id: Int { rawValue }

        var titleKey: String {
            switch self {
            case .nightscout: return "settings.nightscout"
            case .dexcom:     return "settings.dexcom"
            case .libre:      return "settings.libre"
            }
        }
        var subtitleKey: String {
            switch self {
            case .nightscout: return "src.nsSubtitle"
            case .dexcom:     return "src.dexSubtitle"
            case .libre:      return "src.libreSubtitle"
            }
        }
        // Representative marks built from SF Symbols in each service's brand colour —
        // shipping the real logos would need their artwork and their permission.
        var symbol: String {
            switch self {
            case .nightscout: return "moon.stars.fill"
            case .dexcom:     return "drop.fill"
            case .libre:      return "sensor.tag.radiowaves.forward.fill"
            }
        }
        var tile: Color {
            switch self {
            case .nightscout: return Color(hex: "1B2A4A")
            case .dexcom:     return Color(hex: "00A44E")
            case .libre:      return Color(hex: "FFC72C")
            }
        }
        var mark: Color {
            // Libre's yellow needs dark ink on it; the other two take white.
            self == .libre ? Color(hex: "2B2205") : .white
        }
    }

    /// True once credentials exist, whether or not the toggle is on — the pill answers
    /// "have you set this up", not "is it the live source right now".
    private func isConfigured(_ s: WelcomeSource) -> Bool {
        switch s {
        case .nightscout: return glucoseSource.config.isConfigured
        case .dexcom:     return glucoseSource.dexcom.isConfigured
        case .libre:      return glucoseSource.libre.isConfigured
        }
    }

    private func sourceRow(_ s: WelcomeSource, lang: AppLanguage) -> some View {
        let done = isConfigured(s)
        return HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(s.tile)
                Image(systemName: s.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(s.mark)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t(s.titleKey))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(lang.t(s.subtitleKey))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 6)

            Button { editing = s } label: {
                HStack(spacing: 5) {
                    if done { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                    Text(lang.t(done ? "welcome.connected" : "welcome.connect"))
                        .font(.system(size: 14.5, weight: .semibold))
                }
                .foregroundStyle(done ? Theme.green : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(done ? Theme.green.opacity(0.15) : Theme.green, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Theme.sep, lineWidth: 0.5))
    }

    // MARK: - Shared pieces

    private func stepHeading(_ title: String, _ lead: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(lead)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    /// A titled white card holding an editable control.
    @ViewBuilder
    private func fieldBlock<C: View>(title: String, footer: String? = nil,
                                     @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .tracking(0.2)
                .padding(.horizontal, 4)

            content()
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder
    private func choiceBlock<C: View>(title: String, footer: String? = nil,
                                      @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .tracking(0.2)
                .padding(.horizontal, 4)

            VStack(spacing: 0) { content() }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func choiceRow(title: String, selected: Bool, isLast: Bool,
                           action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 16, weight: selected ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? accent : Theme.ink3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isLast {
                Rectangle().fill(Theme.sep).frame(height: 0.5).padding(.leading, 16)
            }
        }
    }
}

#Preview {
    WelcomeView(loc: LocalizationStore(), profileStore: ProfileStore(),
                glucoseSource: GlucoseSourceStore())
        .environmentObject(HealthDataStore())
}
