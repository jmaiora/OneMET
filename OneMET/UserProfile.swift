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

struct UserProfile: Codable, Equatable {
    var name: String = ""
    var diabetesType: DiabetesType = .type1
    var diagnosisYear: Int? = nil
    var weightKg: Double? = nil          // manual override for the MET calculation
    var glucoseLow: Double = 70          // personal target range (mg/dL)
    var glucoseHigh: Double = 180
    var dailyMetGoal: Int = 500          // MET·min ring goal
    var carbRatio: Int = 10              // 1 unit : carbRatio g

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
