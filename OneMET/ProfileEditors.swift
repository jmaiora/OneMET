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

// MARK: - Glucose units

struct EditGlucoseUnitSheet: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var unit: GlucoseUnit

    init(store: ProfileStore) {
        self.store = store
        _unit = State(initialValue: store.profile.glucoseUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Display only — readings are always stored and compared in mg/dL, so switching units never changes your targets or any advice, just how the numbers are written.")) {
                    Picker("Units", selection: $unit) {
                        ForEach(GlucoseUnit.allCases) { Text($0.longName).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
                Section("Preview") {
                    HStack { Text("Current range"); Spacer()
                        Text(unit.range(store.profile.glucoseLow, store.profile.glucoseHigh))
                            .foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Glucose Units")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.profile.glucoseUnit = unit; dismiss() }
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
        // Values are held in mg/dL whatever the display unit; only the label converts.
        let u = store.profile.glucoseUnit
        NavigationStack {
            Form {
                Section(footer: Text("Your personal time-in-range targets. Standard is \(u.range(70, 180)).")) {
                    Stepper(value: $low, in: 50...max(55, high - 10), step: u.stepMgdl) {
                        HStack { Text("Low"); Spacer(); Text(u.amount(low)).foregroundStyle(.secondary) }
                    }
                    Stepper(value: $high, in: min(345, low + 10)...350, step: u.stepMgdl) {
                        HStack { Text("High"); Spacer(); Text(u.amount(high)).foregroundStyle(.secondary) }
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

// MARK: - Insulin delivery

struct EditInsulinDeliverySheet: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var delivery: InsulinDelivery

    init(store: ProfileStore) {
        self.store = store
        _delivery = State(initialValue: store.profile.insulinDelivery)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("How you take insulin. This tailors the Plan tab's before-workout strategy — basal reductions for a pump, meal-bolus timing on injections.")) {
                    Picker("Delivery", selection: $delivery) {
                        ForEach(InsulinDelivery.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Insulin Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.profile.insulinDelivery = delivery; dismiss() }
                }
            }
        }
    }
}

// MARK: - Nightscout glucose source

struct NightscoutSheet: View {
    @ObservedObject var store: GlucoseSourceStore
    @Environment(\.dismiss) private var dismiss

    @State private var url: String
    @State private var secret: String
    @State private var enabled: Bool
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    init(store: GlucoseSourceStore) {
        self.store = store
        _url = State(initialValue: store.config.urlString)
        _secret = State(initialValue: store.config.secret)
        _enabled = State(initialValue: store.config.enabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Nightscout"),
                        footer: Text("Your Nightscout site URL plus an access token (or API secret). Glucose is read directly from Nightscout for lower latency than Apple Health. Read-only.")) {
                    TextField("https://your-site.example.com", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Access token or API secret", text: $secret)
                    Toggle("Use Nightscout for glucose", isOn: $enabled)
                }

                Section {
                    Button {
                        Task {
                            testing = true; testResult = nil
                            let cfg = NightscoutConfig(urlString: url, secret: secret, enabled: true)
                            let ok = await NightscoutClient(config: cfg).test()
                            testOK = ok
                            testResult = ok ? "Connected — recent readings found."
                                            : "Couldn't fetch readings. Check the URL and token."
                            testing = false
                        }
                    } label: {
                        HStack {
                            Text("Test Connection")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(url.isEmpty || testing)

                    if let testResult {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundStyle(testOK ? Color.green : Color.red)
                    }
                }
            }
            .navigationTitle("Glucose Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.config = NightscoutConfig(urlString: url, secret: secret, enabled: enabled)
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Dexcom Share glucose source

struct DexcomSheet: View {
    @ObservedObject var store: GlucoseSourceStore
    @Environment(\.dismiss) private var dismiss

    @State private var username: String
    @State private var password: String
    @State private var ous: Bool
    @State private var enabled: Bool
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    init(store: GlucoseSourceStore) {
        self.store = store
        _username = State(initialValue: store.dexcom.username)
        _password = State(initialValue: store.dexcom.password)
        _ous = State(initialValue: store.dexcom.ous)
        _enabled = State(initialValue: store.dexcom.enabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dexcom Share"),
                        footer: Text("Your Dexcom account with Share/Follow enabled (Sharing ON in the Dexcom app, with at least one follower). Read-only; only recent (~24 h) glucose is available.")) {
                    TextField("Username, email or phone", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                    Picker("Region", selection: $ous) {
                        Text("Outside US").tag(true)
                        Text("United States").tag(false)
                    }
                    Toggle("Use Dexcom for glucose", isOn: $enabled)
                }

                Section {
                    Button {
                        Task {
                            testing = true; testResult = nil
                            let cfg = DexcomConfig(username: username, password: password, ous: ous, enabled: true)
                            let ok = await DexcomShareClient(config: cfg).test()
                            testOK = ok
                            testResult = ok ? "Connected \u{2014} recent readings found."
                                            : "Couldn't fetch readings. Check account, password and region."
                            testing = false
                        }
                    } label: {
                        HStack {
                            Text("Test Connection")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty || testing)

                    if let testResult {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundStyle(testOK ? Color.green : Color.red)
                    }
                }
            }
            .navigationTitle("Dexcom Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.dexcom = DexcomConfig(username: username, password: password, ous: ous, enabled: enabled)
                        dismiss()
                    }
                }
            }
        }
    }
}
