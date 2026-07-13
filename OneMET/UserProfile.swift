import Foundation

// UserProfile.swift — the user's personal data, persisted on-device (UserDefaults).

enum DiabetesType: String, CaseIterable, Codable, Identifiable {
    case type1 = "Type 1"
    case type2 = "Type 2"
    case lada = "LADA"
    case mody = "MODY"
    case gestational = "Gestational"
    case other = "Other"
    var id: String { rawValue }
}

enum InsulinDelivery: String, CaseIterable, Codable, Identifiable, Hashable {
    case pump = "Insulin Pump"
    case mdi  = "Injections (MDI)"
    var id: String { rawValue }
    var isPump: Bool { self == .pump }
    var short: String { self == .pump ? "pump" : "injections" }
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

    enum CodingKeys: String, CodingKey {
        case name, diabetesType, diagnosisYear, weightKg, glucoseLow, glucoseHigh, dailyMetGoal, carbRatio, insulinDelivery
    }

    var isConfigured: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "?" : s
    }

    var displayName: String { isConfigured ? name : "Set up your profile" }

    var subtitle: String {
        guard isConfigured else { return "Tap to add your details" }
        var s = diabetesType.rawValue
        if let y = diagnosisYear { s += " · since \(y)" }
        return s
    }

    var glucoseRangeText: String { "\(Int(glucoseLow))–\(Int(glucoseHigh)) mg/dL" }
    var metGoalText: String { "\(dailyMetGoal) MET·min" }
    var carbRatioText: String { "1 : \(carbRatio)" }
    var weightText: String { weightKg.map { String(format: "%.1f kg", $0) } ?? "Not set" }
    var deliveryText: String { insulinDelivery.rawValue }
}

// Migration-safe decoding: any key missing from an older saved profile falls back
// to its default, so adding fields never wipes a user's saved data.
extension UserProfile: Decodable {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? name
        diabetesType = try c.decodeIfPresent(DiabetesType.self, forKey: .diabetesType) ?? diabetesType
        diagnosisYear = try c.decodeIfPresent(Int.self, forKey: .diagnosisYear) ?? diagnosisYear
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg) ?? weightKg
        glucoseLow = try c.decodeIfPresent(Double.self, forKey: .glucoseLow) ?? glucoseLow
        glucoseHigh = try c.decodeIfPresent(Double.self, forKey: .glucoseHigh) ?? glucoseHigh
        dailyMetGoal = try c.decodeIfPresent(Int.self, forKey: .dailyMetGoal) ?? dailyMetGoal
        carbRatio = try c.decodeIfPresent(Int.self, forKey: .carbRatio) ?? carbRatio
        insulinDelivery = try c.decodeIfPresent(InsulinDelivery.self, forKey: .insulinDelivery) ?? insulinDelivery
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
