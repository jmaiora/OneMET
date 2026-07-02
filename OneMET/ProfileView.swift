import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var hk: HealthKitManager

    var body: some View {
        NavigationView {
            List {
                // Authorization status
                Section {
                    HStack {
                        Image(systemName: hk.isAuthorized ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .foregroundStyle(hk.isAuthorized ? .green : .red)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HealthKit Access")
                                .font(Theme.Font.headline)
                            Text(hk.isAuthorized ? "Granted" : "Not Authorized")
                                .font(Theme.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if !hk.isAuthorized {
                        Button("Request Access") {
                            hk.requestAuthorization()
                        }
                        .tint(Theme.accent)
                    }
                } header: {
                    Text("HealthKit")
                }

                // Data summary
                Section {
                    ProfileRow(label: "Steps Today",     value: "\(hk.stepsToday)", color: Theme.steps)
                    ProfileRow(label: "Active Calories", value: "\(Int(hk.caloriesActive)) kcal", color: Theme.calories)
                    ProfileRow(label: "Heart Rate",      value: "\(Int(hk.heartRateLatest)) bpm", color: Theme.heartRate)
                    ProfileRow(label: "HRV",             value: "\(Int(hk.hrvLatest)) ms",       color: Theme.hrv)
                    ProfileRow(label: "Sleep",           value: String(format: "%.1f hrs", hk.sleepHoursLast), color: Theme.sleep)
                    ProfileRow(label: "Mindfulness",     value: "\(Int(hk.mindfulMinutes)) min", color: Theme.mindfulness)
                } header: {
                    Text("Latest Data")
                }

                // Actions
                Section {
                    Button {
                        hk.fetchAll()
                    } label: {
                        Label("Refresh All Data", systemImage: "arrow.clockwise")
                    }
                    .tint(Theme.accent)
                } header: {
                    Text("Actions")
                }

                // App info
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.jmaiora.onemet")
                } header: {
                    Text("App")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Font.body)
            Spacer()
            Text(value)
                .font(Theme.Font.headline)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(HealthKitManager())
}
