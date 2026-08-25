import Foundation

// GlucoseUnits.swift — display unit for glucose values.
//
// Everything the app stores, computes and compares is in mg/dL; the unit is purely a
// presentation concern. Keeping one canonical internal unit means thresholds (70/180,
// the carb-advice ceiling, Riddell bands) never have to be duplicated per unit.

enum GlucoseUnit: String, CaseIterable, Codable, Identifiable, Hashable {
    case mgdl = "mg/dL"
    case mmol = "mmol/L"

    var id: String { rawValue }
    var isMmol: Bool { self == .mmol }

    /// Full name, for pickers.
    var longName: String {
        self == .mmol ? "mmol/L (millimoles per litre)" : "mg/dL (milligrams per decilitre)"
    }

    /// Glucose molar conversion: 1 mmol/L = 18.0182 mg/dL.
    static let mgdlPerMmol = 18.0182

    /// An absolute reading held in mg/dL, formatted without a unit suffix.
    func value(_ mgdl: Double) -> String {
        isMmol ? String(format: "%.1f", mgdl / Self.mgdlPerMmol)
               : String(Int(mgdl.rounded()))
    }

    /// An absolute reading with its unit, e.g. "38 mg/dL" / "2.1 mmol/L".
    func amount(_ mgdl: Double) -> String { "\(value(mgdl)) \(rawValue)" }

    /// A signed change, e.g. "-38" / "+2.1".
    func delta(_ mgdl: Double) -> String {
        (mgdl > 0 ? "+" : "") + value(mgdl)
    }

    /// A signed change with its unit, e.g. "-38 mg/dL".
    func deltaAmount(_ mgdl: Double) -> String { "\(delta(mgdl)) \(rawValue)" }

    /// A range with a single trailing unit, e.g. "140–180 mg/dL".
    func range(_ low: Double, _ high: Double) -> String {
        "\(value(low))\u{2013}\(value(high)) \(rawValue)"
    }

    /// Step size for steppers, in mg/dL — 5 mg/dL is too coarse to land on round
    /// mmol/L values, so mmol users step by ~0.1 mmol/L instead.
    var stepMgdl: Double { isMmol ? Self.mgdlPerMmol / 10 : 5 }
}
