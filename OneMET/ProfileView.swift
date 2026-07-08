import SwiftUI

// ProfileView.swift — OneMET Profile screen with editable personal data.

enum ProfileEditor: Int, Identifiable {
    case identity, glucose, met, carb
    var id: Int { rawValue }
}

struct ProfileView: View {
    @EnvironmentObject var store: HealthDataStore
    @EnvironmentObject var profileStore: ProfileStore
    var accent: Color

    @State private var editor: ProfileEditor?

    var body: some View {
        let p = profileStore.profile

        ScreenScaffold(spacing: 18) {
            AppHeader(title: "Profile", date: "Account", accent: accent)

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
                        Text(p.displayName)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(p.isConfigured ? Theme.ink : Theme.ink2)
                        Text(p.subtitle)
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

            IOSList(header: "Connected Devices") {
                IOSListRow(title: "CGM Sensor",
                           detail: store.authorized ? "Connected" : "Not linked",
                           dot: store.authorized ? Theme.green : Theme.ink3)
                IOSListRow(title: "Apple Watch", detail: "Series 9", dot: Theme.red)
                IOSListRow(title: "Insulin Pen", detail: "Synced 9:41", dot: accent, isLast: true)
            }

            IOSList(header: "Personal Targets") {
                IOSListRow(title: "Glucose Range", detail: p.glucoseRangeText, dot: Theme.green) { editor = .glucose }
                IOSListRow(title: "Daily MET Goal", detail: p.metGoalText, dot: Theme.ringMet) { editor = .met }
                IOSListRow(title: "Carb Ratio", detail: p.carbRatioText, dot: Theme.amber, isLast: true) { editor = .carb }
            }

            IOSList(header: "Body") {
                IOSListRow(title: "Weight", detail: p.weightText, dot: Theme.teal, isLast: true) { editor = .identity }
            }

            IOSList(header: "Data") {
                IOSListRow(title: "Export Health Report", dot: accent)
                IOSListRow(title: "Share with Clinician", dot: Theme.teal)
                IOSListRow(title: "Notifications", dot: Theme.violet, isLast: true)
            }
        }
        .sheet(item: $editor) { which in
            switch which {
            case .identity: EditIdentitySheet(store: profileStore)
            case .glucose:  EditGlucoseRangeSheet(store: profileStore)
            case .met:      EditMetGoalSheet(store: profileStore)
            case .carb:     EditCarbRatioSheet(store: profileStore)
            }
        }
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); ProfileView(accent: Theme.accent)
        .environmentObject(HealthDataStore())
        .environmentObject(ProfileStore())
    }
}
