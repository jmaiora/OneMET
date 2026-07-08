import SwiftUI

// ProfileEditors.swift — edit sheets for the user's personal data.

private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

// MARK: - Identity + weight

struct EditIdentitySheet: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: UserProfile
    @State private var hasYear: Bool
    @State private var year: Int
    @State private var weightText: String

    init(store: ProfileStore) {
        self.store = store
        let p = store.profile
        _draft = State(initialValue: p)
        _hasYear = State(initialValue: p.diagnosisYear != nil)
        _year = State(initialValue: p.diagnosisYear ?? currentYear)
        _weightText = State(initialValue: p.weightKg.map { String(format: "%.1f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    Picker("Diabetes type", selection: $draft.diabetesType) {
                        ForEach(DiabetesType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Set diagnosis year", isOn: $hasYear.animation())
                    if hasYear {
                        Stepper(value: $year, in: 1940...currentYear) {
                            HStack { Text("Diagnosis year"); Spacer()
                                Text(String(year)).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section(header: Text("Body"),
                        footer: Text("Used for the MET·min calculation. Leave blank to use your Apple Health weight.")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.diagnosisYear = hasYear ? year : nil
                        let cleaned = weightText.replacingOccurrences(of: ",", with: ".")
                        draft.weightKg = cleaned.isEmpty ? nil : Double(cleaned)
                        store.profile = draft
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Glucose range

struct EditGlucoseRangeSheet: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var low: Double
    @State private var high: Double

    init(store: ProfileStore) {
        self.store = store
        _low = State(initialValue: store.profile.glucoseLow)
        _high = State(initialValue: store.profile.glucoseHigh)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Your personal time-in-range targets. Standard is 70–180 mg/dL.")) {
                    Stepper(value: $low, in: 50...max(55, high - 10), step: 5) {
                        HStack { Text("Low"); Spacer(); Text("\(Int(low)) mg/dL").foregroundStyle(.secondary) }
                    }
                    Stepper(value: $high, in: min(345, low + 10)...350, step: 5) {
                        HStack { Text("High"); Spacer(); Text("\(Int(high)) mg/dL").foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Glucose Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.profile.glucoseLow = low
                        store.profile.glucoseHigh = high
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - MET goal

struct EditMetGoalSheet: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Int

    init(store: ProfileStore) {
        self.store = store
        _goal = State(initialValue: store.profile.dailyMetGoal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Target MET·minutes per day. A brisk walk is ~3–4 MET; running ~8–10 MET.")) {
                    Stepper(value: $goal, in: 100...1500, step: 10) {
                        HStack { Text("Daily goal"); Spacer(); Text("\(goal) MET·min").foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Daily MET Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.profile.dailyMetGoal = goal; dismiss() }
                }
            }
        }
    }
}

// MARK: - Carb ratio

struct EditCarbRatioSheet: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var ratio: Int

    init(store: ProfileStore) {
        self.store = store
        _ratio = State(initialValue: store.profile.carbRatio)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Insulin-to-carb ratio: 1 unit covers this many grams of carbohydrate.")) {
                    Stepper(value: $ratio, in: 3...40) {
                        HStack { Text("Ratio"); Spacer(); Text("1 : \(ratio)").foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Carb Ratio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.profile.carbRatio = ratio; dismiss() }
                }
            }
        }
    }
}
