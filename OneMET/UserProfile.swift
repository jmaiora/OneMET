import Foundation

// UserProfile.swift — the user's personal data, persisted on-device (UserDefaults).

// Raw values are stable storage ids and double as localization key suffixes; nothing
// displays them directly, so renaming a label never invalidates a saved profile.
enum DiabetesType: String, CaseIterable, Codable, Identifiable {
    case type1, type2, lada, mody, gestational, nonDiabetic, other
    var id: String { rawValue }
    func label(_ lang: AppLanguage) -> String { lang.t("dtype.\(rawValue)") }

    /// No diagnosis, so nothing to date — setup hides the year for this one.
    var hasDiagnosis: Bool { self != .nonDiabetic }

    /// The three offered during first-run setup; the rarer types stay in the full picker
    /// in Settings so the onboarding question is a quick three-way choice.
    static let onboardingChoices: [DiabetesType] = [.type1, .type2, .nonDiabetic]

    /// True where exogenous insulin is part of the definition, so there's no point asking.
    var impliesInsulin: Bool { self == .type1 || self == .lada }
}

enum InsulinDelivery: String, CaseIterable, Codable, Identifiable, Hashable {
    // `noInsulin` rather than `none`, which shadows Optional.none at call sites.
    case pump, mdi, noInsulin
    var id: String { rawValue }
    var isPump: Bool { self == .pump }
    /// The variable that actually drives exercise hypoglycaemia risk — see
    /// `UserProfile.fuellingModelApplies`.
    var usesInsulin: Bool { self != .noInsulin }
    func label(_ lang: AppLanguage) -> String { lang.t("insulin.\(rawValue)") }
}

// Profiles saved before localization stored the English display string as the raw value
// ("Type 1", "Insulin Pump"). Decoding those against the new ids would throw and take
// the whole profile down with it, so both types accept either spelling.
extension DiabetesType {
    init?(stored raw: String) {
        if let v = DiabetesType(rawValue: raw) { self = v; return }
        switch raw.lowercased() {
        case "type 1":      self = .type1
        case "type 2":      self = .type2
        case "lada":        self = .lada
        case "mody":        self = .mody
        case "gestational": self = .gestational
        case "other":       self = .other
        default:            return nil
        }
    }
}

extension InsulinDelivery {
    init?(stored raw: String) {
        if let v = InsulinDelivery(rawValue: raw) { self = v; return }
        switch raw.lowercased() {
        case "insulin pump":     self = .pump
        case "injections (mdi)": self = .mdi
        case "none", "no insulin": self = .noInsulin
        default:                 return nil
        }
    }
}

struct UserProfile: Encodable, Equatable {
    var name: String = ""
    var diabetesType: DiabetesType = .type1
    var diagnosisYear: Int? = nil
    var weightKg: Double? = nil          // manual override for the MET calculation
    var glucoseLow: Double = 70          // personal target range (mg/dL)
    var glucoseHigh: Double = 180
    var dailyMetGoal: Int = 500          // MET·min ring goal
    var carbRatio: Int = 10              // 1 unit : carbRatio g
    var insulinDelivery: InsulinDelivery = .pump   // drives EXTOD carb rates in the Plan tab
    var glucoseUnit: GlucoseUnit = .mgdl // display only — everything is stored in mg/dL

    enum CodingKeys: String, CodingKey {
        case name, diabetesType, diagnosisYear, weightKg, glucoseLow, glucoseHigh, dailyMetGoal, carbRatio, insulinDelivery, glucoseUnit
    }

    var isConfigured: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "?" : s
    }

    /// Whether the Plan tab's carbohydrate model applies to this person.
    ///
    /// It was derived for type 1 diabetes on exogenous insulin (Riddell 2017 / EXTOD), and
    /// the hypoglycaemia it exists to prevent comes from the *insulin*, not the diagnosis.
    /// Type 2 on metformin, a GLP-1 agonist or an SGLT2 inhibitor carries little exercise
    /// hypoglycaemia risk, so prophylactic carbohydrate would work directly against the
    /// glycaemic benefit that makes the exercise worth doing. Without diabetes, glucose is
    /// counter-regulated normally and fuelling becomes a performance question instead.
    ///
    /// So the gate is insulin use, with the two insulin-requiring diagnoses short-circuited.
    var fuellingModelApplies: Bool {
        if diabetesType == .nonDiabetic { return false }
        if diabetesType.impliesInsulin { return true }
        return insulinDelivery.usesInsulin
    }

    var glucoseRangeText: String { glucoseUnit.range(glucoseLow, glucoseHigh) }
    var metGoalText: String { "\(dailyMetGoal) MET·min" }
    var carbRatioText: String { "1 : \(carbRatio)" }
    /// Empty when unset — SettingsView substitutes the localized "Not set".
    var weightText: String { weightKg.map { String(format: "%.1f kg", $0) } ?? "" }
}

// Migration-safe decoding: any key missing from an older saved profile falls back
// to its default, so adding fields never wipes a user's saved data.
extension UserProfile: Decodable {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? name
        // Decoded as raw strings so legacy display-string values still map (see above).
        if let raw = try? c.decodeIfPresent(String.self, forKey: .diabetesType),
           let v = DiabetesType(stored: raw) { diabetesType = v }
        diagnosisYear = try c.decodeIfPresent(Int.self, forKey: .diagnosisYear) ?? diagnosisYear
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg) ?? weightKg
        glucoseLow = try c.decodeIfPresent(Double.self, forKey: .glucoseLow) ?? glucoseLow
        glucoseHigh = try c.decodeIfPresent(Double.self, forKey: .glucoseHigh) ?? glucoseHigh
        dailyMetGoal = try c.decodeIfPresent(Int.self, forKey: .dailyMetGoal) ?? dailyMetGoal
        carbRatio = try c.decodeIfPresent(Int.self, forKey: .carbRatio) ?? carbRatio
        if let raw = try? c.decodeIfPresent(String.self, forKey: .insulinDelivery),
           let v = InsulinDelivery(stored: raw) { insulinDelivery = v }
        glucoseUnit = try c.decodeIfPresent(GlucoseUnit.self, forKey: .glucoseUnit) ?? glucoseUnit
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile: UserProfile { didSet { save() } }

    private let key = "onemet.userProfile.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let p = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = p
        } else {
            profile = UserProfile()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
