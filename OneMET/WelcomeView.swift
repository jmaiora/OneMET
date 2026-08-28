import SwiftUI

// WelcomeView.swift — first-run setup.
//
// Language, units, and optionally a glucose source. Everything here is cheap to change
// later in Settings, so it stays one screen rather than a wizard — the point is to get
// the app speaking the right language and reading the right sensor before anything else
// is looked at. The language picker updates the rest of this screen live as you tap it.
//
// The source rows are deliberately skippable: with none connected, glucose comes from
// Apple Health, which is enough to use the app.

struct WelcomeView: View {
    @ObservedObject var loc: LocalizationStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var glucoseSource: GlucoseSourceStore
    var accent: Color = Theme.accent

    /// Held locally and committed on "Get started", except language, which applies
    /// immediately so you can see the screen change into the language you chose.
    @State private var unit: GlucoseUnit = .mgdl
    @State private var editing: WelcomeSource?

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

    var body: some View {
        let lang = loc.language

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {

                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent)
                        AppIconView(name: "drop", color: .white, size: 30)
                    }
                    .frame(width: 62, height: 62)
                    .padding(.bottom, 6)

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
                .padding(.top, 40)

                // Language — applied live, so the screen redraws in the chosen language.
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

                // Glucose source — optional, and each row opens the same sheet Settings
                // uses, so there's one place where connecting is implemented.
                VStack(alignment: .leading, spacing: 7) {
                    Text(lang.t("welcome.sources").uppercased())
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .tracking(0.2)
                        .padding(.horizontal, 4)

                    VStack(spacing: 10) {
                        ForEach(WelcomeSource.allCases) { sourceRow($0, lang: lang) }
                    }

                    Text(lang.t("welcome.sourcesNote"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                Button {
                    profileStore.profile.glucoseUnit = unit
                    // Flipping this is what dismisses the screen — RootView shows it
                    // only while hasOnboarded is false.
                    withAnimation(.easeInOut(duration: 0.3)) { loc.hasOnboarded = true }
                } label: {
                    Text(lang.t("welcome.start"))
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
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { unit = profileStore.profile.glucoseUnit }
        .sheet(item: $editing) { which in
            switch which {
            case .nightscout: NightscoutSheet(store: glucoseSource, lang: loc.language)
            case .dexcom:     DexcomSheet(store: glucoseSource, lang: loc.language)
            case .libre:      LibreLinkUpSheet(store: glucoseSource, lang: loc.language)
            }
        }
    }

    // MARK: - Glucose source row

    /// True once credentials exist, whether or not the toggle is on — the point of the
    /// pill is "have you set this up", not "is it currently the live source".
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

    // MARK: - Pieces

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
}
