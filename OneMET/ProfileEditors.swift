import SwiftUI

// ProfileEditors.swift — edit sheets for the user's personal data and app settings.

private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

// MARK: - Identity + weight

struct EditIdentitySheet: View {
    @ObservedObject var store: ProfileStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss

    @State private var draft: UserProfile
    @State private var hasYear: Bool
    @State private var year: Int
    @State private var weightText: String

    init(store: ProfileStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        let p = store.profile
        _draft = State(initialValue: p)
        _hasYear = State(initialValue: p.diagnosisYear != nil)
        _year = State(initialValue: p.diagnosisYear ?? currentYear)
        _weightText = State(initialValue: p.weightKg.map { String(format: "%.1f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang.t("edit.identity")) {
                    TextField(lang.t("edit.name"), text: $draft.name)
                        .textInputAutocapitalization(.words)
                    Picker(lang.t("edit.diabetesType"), selection: $draft.diabetesType) {
                        ForEach(DiabetesType.allCases) { Text($0.label(lang)).tag($0) }
                    }
                    // Nothing to date without a diagnosis — this is the only place the
                    // year is asked now, setup having dropped it.
                    if draft.diabetesType.hasDiagnosis {
                        Toggle(lang.t("edit.setDiagYear"), isOn: $hasYear.animation())
                    }
                    if hasYear && draft.diabetesType.hasDiagnosis {
                        Stepper(value: $year, in: 1940...currentYear) {
                            HStack { Text(lang.t("edit.diagYear")); Spacer()
                                Text(String(year)).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section(header: Text(lang.t("settings.body")),
                        footer: Text(lang.t("edit.weightFooter"))) {
                    HStack {
                        Text(lang.t("settings.weight"))
                        Spacer()
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(lang.t("edit.profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) {
                        draft.diagnosisYear = (hasYear && draft.diabetesType.hasDiagnosis) ? year : nil
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

// MARK: - Language

struct EditLanguageSheet: View {
    @ObservedObject var loc: LocalizationStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss
    @State private var choice: AppLanguage

    init(loc: LocalizationStore, lang: AppLanguage = .en) {
        self.loc = loc
        self.lang = lang
        _choice = State(initialValue: loc.language)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(lang.t("edit.langFooter"))) {
                    Picker(lang.t("edit.langTitle"), selection: $choice) {
                        // Each option is written in its own language, never translated.
                        ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle(lang.t("edit.langTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) { loc.language = choice; dismiss() }
                }
            }
        }
    }
}

// MARK: - Glucose units

struct EditGlucoseUnitSheet: View {
    @ObservedObject var store: ProfileStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss
    @State private var unit: GlucoseUnit

    init(store: ProfileStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _unit = State(initialValue: store.profile.glucoseUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(lang.t("edit.unitsFooter"))) {
                    Picker(lang.t("edit.unitsTitle"), selection: $unit) {
                        ForEach(GlucoseUnit.allCases) { Text($0.longName).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
                Section(lang.t("common.preview")) {
                    HStack { Text(lang.t("edit.currentRange")); Spacer()
                        Text(unit.range(store.profile.glucoseLow, store.profile.glucoseHigh))
                            .foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(lang.t("edit.unitsTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) { store.profile.glucoseUnit = unit; dismiss() }
                }
            }
        }
    }
}

// MARK: - Glucose range

struct EditGlucoseRangeSheet: View {
    @ObservedObject var store: ProfileStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss
    @State private var low: Double
    @State private var high: Double

    init(store: ProfileStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _low = State(initialValue: store.profile.glucoseLow)
        _high = State(initialValue: store.profile.glucoseHigh)
    }

    var body: some View {
        // Values are held in mg/dL whatever the display unit; only the label converts.
        let u = store.profile.glucoseUnit
        NavigationStack {
            Form {
                Section(footer: Text(lang.t("edit.rangeFooter", u.range(70, 180)))) {
                    Stepper(value: $low, in: 50...max(55, high - 10), step: u.stepMgdl) {
                        HStack { Text(lang.t("edit.rangeLow")); Spacer(); Text(u.amount(low)).foregroundStyle(.secondary) }
                    }
                    Stepper(value: $high, in: min(345, low + 10)...350, step: u.stepMgdl) {
                        HStack { Text(lang.t("edit.rangeHigh")); Spacer(); Text(u.amount(high)).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle(lang.t("edit.rangeTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) {
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
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Int

    init(store: ProfileStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _goal = State(initialValue: store.profile.dailyMetGoal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(lang.t("edit.metFooter"))) {
                    Stepper(value: $goal, in: 100...1500, step: 10) {
                        HStack { Text(lang.t("edit.metGoal")); Spacer(); Text("\(goal) MET·min").foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle(lang.t("edit.metTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) { store.profile.dailyMetGoal = goal; dismiss() }
                }
            }
        }
    }
}

// MARK: - Carb ratio

struct EditCarbRatioSheet: View {
    @ObservedObject var store: ProfileStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss
    @State private var ratio: Int

    init(store: ProfileStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _ratio = State(initialValue: store.profile.carbRatio)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(lang.t("edit.carbFooter"))) {
                    Stepper(value: $ratio, in: 3...40) {
                        HStack { Text(lang.t("edit.carbRatio")); Spacer(); Text("1 : \(ratio)").foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle(lang.t("edit.carbTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) { store.profile.carbRatio = ratio; dismiss() }
                }
            }
        }
    }
}

// MARK: - Insulin delivery

struct EditInsulinDeliverySheet: View {
    @ObservedObject var store: ProfileStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss
    @State private var delivery: InsulinDelivery

    init(store: ProfileStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _delivery = State(initialValue: store.profile.insulinDelivery)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(lang.t("edit.insulinFooter"))) {
                    Picker(lang.t("edit.delivery"), selection: $delivery) {
                        ForEach(InsulinDelivery.allCases) { Text($0.label(lang)).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle(lang.t("edit.insulinTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) { store.profile.insulinDelivery = delivery; dismiss() }
                }
            }
        }
    }
}

// MARK: - Nightscout glucose source

struct NightscoutSheet: View {
    @ObservedObject var store: GlucoseSourceStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss

    @State private var url: String
    @State private var secret: String
    @State private var enabled: Bool
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    init(store: GlucoseSourceStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _url = State(initialValue: store.config.urlString)
        _secret = State(initialValue: store.config.secret)
        _enabled = State(initialValue: store.config.enabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(lang.t("settings.nightscout")),
                        footer: Text(lang.t("src.nsFooter"))) {
                    TextField("https://your-site.example.com", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField(lang.t("src.token"), text: $secret)
                    Toggle(lang.t("src.useNs"), isOn: $enabled)
                }

                Section {
                    Button {
                        Task {
                            testing = true; testResult = nil
                            let cfg = NightscoutConfig(urlString: url, secret: secret, enabled: true)
                            let ok = await NightscoutClient(config: cfg).test()
                            testOK = ok
                            testResult = lang.t(ok ? "src.testOk" : "src.testFailNs")
                            testing = false
                        }
                    } label: {
                        HStack {
                            Text(lang.t("src.test"))
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
            .navigationTitle(lang.t("src.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) {
                        store.config = NightscoutConfig(urlString: url, secret: secret, enabled: enabled)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - LibreLinkUp glucose source

struct LibreLinkUpSheet: View {
    @ObservedObject var store: GlucoseSourceStore
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var password: String
    @State private var region: String
    @State private var enabled: Bool
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    init(store: GlucoseSourceStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _email = State(initialValue: store.libre.email)
        _password = State(initialValue: store.libre.password)
        _region = State(initialValue: store.libre.region)
        _enabled = State(initialValue: store.libre.enabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(lang.t("settings.libre")),
                        footer: Text(lang.t("src.libreFooter"))) {
                    TextField(lang.t("src.libreEmail"), text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    SecureField(lang.t("src.password"), text: $password)
                    Toggle(lang.t("src.useLibre"), isOn: $enabled)
                }

                Section(footer: Text(lang.t("src.libreRegionAuto"))) {
                    Picker(lang.t("src.region"), selection: $region) {
                        // Abbott shards accounts by region; testing the connection corrects
                        // this automatically, so it rarely needs touching by hand.
                        ForEach(LibreLinkUpClient.regions, id: \.self) {
                            Text($0.uppercased()).tag($0)
                        }
                    }
                }

                Section {
                    Button {
                        Task {
                            testing = true; testResult = nil
                            var cfg = LibreLinkUpConfig(email: email, password: password,
                                                        region: region, enabled: true)
                            let client = LibreLinkUpClient(config: cfg)
                            // Adopt whatever region the login redirects to before testing.
                            if let detected = await client.detectRegion(), detected != region {
                                region = detected
                                cfg.region = detected
                            }
                            let ok = await LibreLinkUpClient(config: cfg).test()
                            testOK = ok
                            testResult = lang.t(ok ? "src.testOk" : "src.testFailLibre")
                            testing = false
                        }
                    } label: {
                        HStack {
                            Text(lang.t("src.test"))
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || testing)

                    if let testResult {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundStyle(testOK ? Color.green : Color.red)
                    }
                }
            }
            .navigationTitle(lang.t("settings.libre"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) {
                        store.libre = LibreLinkUpConfig(email: email, password: password,
                                                        region: region, enabled: enabled)
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
    var lang: AppLanguage = .en
    @Environment(\.dismiss) private var dismiss

    @State private var username: String
    @State private var password: String
    @State private var ous: Bool
    @State private var enabled: Bool
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    init(store: GlucoseSourceStore, lang: AppLanguage = .en) {
        self.store = store
        self.lang = lang
        _username = State(initialValue: store.dexcom.username)
        _password = State(initialValue: store.dexcom.password)
        _ous = State(initialValue: store.dexcom.ous)
        _enabled = State(initialValue: store.dexcom.enabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(lang.t("settings.dexcom")),
                        footer: Text(lang.t("src.dexFooter"))) {
                    TextField(lang.t("src.username"), text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    SecureField(lang.t("src.password"), text: $password)
                    Picker(lang.t("src.region"), selection: $ous) {
                        Text(lang.t("src.outsideUs")).tag(true)
                        Text(lang.t("src.us")).tag(false)
                    }
                    Toggle(lang.t("src.useDexcom"), isOn: $enabled)
                }

                Section {
                    Button {
                        Task {
                            testing = true; testResult = nil
                            let cfg = DexcomConfig(username: username, password: password, ous: ous, enabled: true)
                            let ok = await DexcomShareClient(config: cfg).test()
                            testOK = ok
                            testResult = lang.t(ok ? "src.testOk" : "src.testFailDex")
                            testing = false
                        }
                    } label: {
                        HStack {
                            Text(lang.t("src.test"))
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
            .navigationTitle(lang.t("settings.dexcom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang.t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("common.save")) {
                        store.dexcom = DexcomConfig(username: username, password: password, ous: ous, enabled: enabled)
                        dismiss()
                    }
                }
            }
        }
    }
}
