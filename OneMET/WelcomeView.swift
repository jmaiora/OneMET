import SwiftUI

// WelcomeView.swift — first-run setup.
//
// Two choices only: language and glucose units. Both are cheap to change later in
// Settings, so this stays a single screen rather than a wizard — the point is to get
// the app speaking the right language before anything else is read, not to collect a
// profile. The language picker updates the rest of this screen live as you tap it.

struct WelcomeView: View {
    @ObservedObject var loc: LocalizationStore
    @ObservedObject var profileStore: ProfileStore
    var accent: Color = Theme.accent

    /// Held locally and committed on "Get started", except language, which applies
    /// immediately so you can see the screen change into the language you chose.
    @State private var unit: GlucoseUnit = .mgdl

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
    WelcomeView(loc: LocalizationStore(), profileStore: ProfileStore())
}
