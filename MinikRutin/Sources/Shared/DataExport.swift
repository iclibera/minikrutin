import Foundation

/// Exports all of a baby's data as a JSON file the user can keep or move
/// elsewhere (Guideline 5.1.1 — data portability).
enum DataExport {
    static func export(baby: Baby, entries: [LogEntry]) -> URL? {
        var dict: [String: Any] = [
            "app": "MinikRutin",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "baby": [
                "name": baby.name,
                "birthDate": ISO8601DateFormatter().string(from: baby.birthDate),
                "gender": baby.genderRaw,
            ],
        ]
        let iso = ISO8601DateFormatter()
        dict["entries"] = entries.filter { !$0.deleted }.map { e -> [String: Any] in
            var d: [String: Any] = ["type": e.typeRaw, "date": iso.string(from: e.date)]
            if let v = e.endDate { d["endDate"] = iso.string(from: v) }
            if let v = e.feedingTypeRaw { d["feedingType"] = v }
            if let v = e.amountML { d["amountML"] = v }
            if let v = e.durationMin { d["durationMin"] = v }
            if let v = e.sideRaw { d["side"] = v }
            if let v = e.diaperKindRaw { d["diaperKind"] = v }
            if let v = e.medName { d["medName"] = v }
            if let v = e.dose { d["dose"] = v }
            if let v = e.temperatureC { d["temperatureC"] = v }
            if let v = e.weightKg { d["weightKg"] = v }
            if let v = e.heightCm { d["heightCm"] = v }
            if let v = e.headCm { d["headCm"] = v }
            if let v = e.vaccineName { d["vaccineName"] = v; d["vaccineDone"] = e.vaccineDone }
            if let v = e.text { d["text"] = v }
            if !e.tags.isEmpty { d["tags"] = e.tags }
            return d
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MinikRutin-\(baby.name)-veri.json")
        do { try data.write(to: url); return url } catch { return nil }
    }
}
