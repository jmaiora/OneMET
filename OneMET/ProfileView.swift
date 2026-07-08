import SwiftUI

// ProfileView.swift — OneMET Profile screen.

struct ProfileView: View {
    @EnvironmentObject var store: HealthDataStore
    var accent: Color

    var body: some View {
        let d = store.data
        let range = "\(Int(Theme.targetLow))–\(Int(Theme.targetHigh)) mg/dL"
        let metGoal = "\(Int(d.rings.met.goal)) MET·min"

        ScreenScaffold(spacing: 18) {
            AppHeader(title: "Profile", date: "Account", accent: accent)

            // Identity row
            HStack(spacing: 14) {
                Text("AM")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(accent)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alex Moreno")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Type 1 · since 2014")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            IOSList(header: "Connected Devices") {
                IOSListRow(title: "CGM Sensor", detail: store.authorized ? "Connected" : "Not linked", dot: store.authorized ? Theme.green : Theme.ink3)
                IOSListRow(title: "Apple Watch", detail: "Series 9", dot: Theme.red)
                IOSListRow(title: "Insulin Pen", detail: "Synced 9:41", dot: accent, isLast: true)
            }

            IOSList(header: "Targets") {
                IOSListRow(title: "Glucose Range", detail: range, dot: Theme.green)
                IOSListRow(title: "Daily MET Goal", detail: metGoal, dot: Theme.ringMet)
                IOSListRow(title: "Carb Ratio", detail: "1 : 10", dot: Theme.amber, isLast: true)
            }

            IOSList(header: "Data") {
                IOSListRow(title: "Export Health Report", dot: accent)
                IOSListRow(title: "Share with Clinician", dot: Theme.teal)
                IOSListRow(title: "Notifications", dot: Theme.violet, isLast: true)
            }
        }
    }
}

#Preview {
    ZStack { Theme.bg.ignoresSafeArea(); ProfileView(accent: Theme.accent).environmentObject(HealthDataStore()) }
}
