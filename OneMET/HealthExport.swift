import SwiftUI
import UIKit

// HealthExport.swift — build a downloadable .xlsx of workout details and share it.
// The .xlsx is written by hand as a "stored" (uncompressed) ZIP of the minimal
// OpenXML parts, so there are no third-party dependencies. The exact byte layout
// was validated against a real spreadsheet reader before porting here.

/// Wrapper so a generated file URL can drive a SwiftUI `.sheet(item:)`.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

enum WorkoutExport {

    /// Column order for the exported sheet.
    private static let headers = ["Date", "Time", "Sport", "Duration (min)",
                                  "Distance", "Calories", "Avg MET", "Avg HR",
                                  "Glucose Δ (mg/dL)"]

    /// Build an .xlsx workbook of every session in the workout history.
    static func xlsx(history: [WorkoutWeek]) -> Data {
        let sessions = history.flatMap { $0.sessions }
        var rows: [[Cell]] = [headers.map { .text($0) }]
        for s in sessions {
            rows.append([
                .text(s.day), .text(s.time), .text(s.name),
                .number(Double(s.durMin)), .text(s.dist),
                .number(Double(s.kcal)), .number(s.avgMet),
                .number(Double(s.hr)), .number(Double(s.glucoseDelta)),
            ])
        }
        return zipStored(parts: parts(rows: rows))
    }

    // MARK: - Cell model

    private enum Cell {
        case text(String)
        case number(Double)
    }

    // MARK: - OpenXML parts

    private static func colLetter(_ index: Int) -> String {
        var i = index + 1, s = ""
        while i > 0 {
            let r = (i - 1) % 26
            s = String(UnicodeScalar(65 + r)!) + s
            i = (i - 1) / 26
        }
        return s
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func numStr(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }

    private static func parts(rows: [[Cell]]) -> [(name: String, text: String)] {
        var sheetRows = ""
        for (ri, row) in rows.enumerated() {
            let r = ri + 1
            var cells = ""
            for (ci, cell) in row.enumerated() {
                let ref = "\(colLetter(ci))\(r)"
                switch cell {
                case .number(let v):
                    cells += "<c r=\"\(ref)\"><v>\(numStr(v))</v></c>"
                case .text(let t):
                    cells += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(esc(t))</t></is></c>"
                }
            }
            sheetRows += "<row r=\"\(r)\">\(cells)</row>"
        }
        let sheet = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
            + "<sheetData>\(sheetRows)</sheetData></worksheet>"

        let contentTypes = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
            + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
            + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
            + "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
            + "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
            + "</Types>"

        let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
            + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>"
            + "</Relationships>"

        let workbook = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" "
            + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
            + "<sheets><sheet name=\"Workouts\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>"

        let workbookRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
            + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>"
            + "</Relationships>"

        return [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", rels),
            ("xl/workbook.xml", workbook),
            ("xl/_rels/workbook.xml.rels", workbookRels),
            ("xl/worksheets/sheet1.xml", sheet),
        ]
    }

    // MARK: - Minimal ZIP writer (stored / method 0)

    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in bytes {
            crc ^= UInt32(b)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : (crc >> 1)
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    private static func zipStored(parts: [(name: String, text: String)]) -> Data {
        var out = Data()
        var central = Data()
        var offset = 0

        func u16(_ v: Int) -> Data { var x = UInt16(truncatingIfNeeded: v).littleEndian; return Data(bytes: &x, count: 2) }
        func u32(_ v: UInt32) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 4) }
        func u32i(_ v: Int) -> Data { u32(UInt32(truncatingIfNeeded: v)) }

        for part in parts {
            let nameBytes = Array(part.name.utf8)
            let data = Array(part.text.utf8)
            let crc = crc32(data)

            // Local file header
            var lfh = Data()
            lfh.append(u32(0x0403_4b50))
            lfh.append(u16(20)); lfh.append(u16(0)); lfh.append(u16(0))
            lfh.append(u16(0)); lfh.append(u16(0))
            lfh.append(u32(crc)); lfh.append(u32i(data.count)); lfh.append(u32i(data.count))
            lfh.append(u16(nameBytes.count)); lfh.append(u16(0))
            lfh.append(contentsOf: nameBytes)
            out.append(lfh)
            out.append(contentsOf: data)

            // Central directory header
            var cdh = Data()
            cdh.append(u32(0x0201_4b50))
            cdh.append(u16(20)); cdh.append(u16(20)); cdh.append(u16(0)); cdh.append(u16(0))
            cdh.append(u16(0)); cdh.append(u16(0))
            cdh.append(u32(crc)); cdh.append(u32i(data.count)); cdh.append(u32i(data.count))
            cdh.append(u16(nameBytes.count)); cdh.append(u16(0)); cdh.append(u16(0))
            cdh.append(u16(0)); cdh.append(u16(0)); cdh.append(u32i(0)); cdh.append(u32i(offset))
            cdh.append(contentsOf: nameBytes)
            central.append(cdh)

            offset += lfh.count + data.count
        }

        let cdStart = offset
        out.append(central)

        // End of central directory
        var eocd = Data()
        eocd.append(u32(0x0605_4b50))
        eocd.append(u16(0)); eocd.append(u16(0))
        eocd.append(u16(parts.count)); eocd.append(u16(parts.count))
        eocd.append(u32i(central.count)); eocd.append(u32i(cdStart)); eocd.append(u16(0))
        out.append(eocd)
        return out
    }
}

// MARK: - Share sheet

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
