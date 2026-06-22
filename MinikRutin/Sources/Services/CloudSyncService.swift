import Foundation
import SwiftData

/// Best-effort cloud sync of babies + log entries against Firestore over REST.
/// SwiftData remains the on-device source of truth; this layer mirrors data so
/// it survives device loss and can be shared with caregivers. Photos are NOT
/// uploaded — only structured records.
@MainActor
final class CloudSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSync: Date?
    @Published var lastError: String?

    private let auth: AuthService
    init(auth: AuthService) { self.auth = auth }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: Public

    /// Two-way sync for the signed-in user. Pushes local changes, then pulls
    /// remote state and merges by `updatedAt` (last write wins).
    func syncNow(context: ModelContext) async {
        guard FirebaseConfig.isConfigured, auth.isSignedIn,
              let uid = auth.uid, let token = try? await auth.validToken() else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            try await pushLocal(context: context, uid: uid, token: token)
            try await pullRemote(context: context, uid: uid, token: token)
            try? context.save()
            lastSync = Date()
        } catch {
            lastError = (error as NSError).localizedDescription
        }
    }

    // MARK: Push

    private func pushLocal(context: ModelContext, uid: String, token: String) async throws {
        let babies = try context.fetch(FetchDescriptor<Baby>())
        for baby in babies where (baby.ownerUID == uid || baby.memberUIDs.contains(uid)) {
            if baby.ownerUID == nil { baby.ownerUID = uid }
            if !baby.memberUIDs.contains(uid) { baby.memberUIDs.append(uid) }
            try await put(path: "babies/\(baby.id)", fields: babyFields(baby), token: token)
        }
        let entries = try context.fetch(FetchDescriptor<LogEntry>())
        let ownIDs = Set(babies.map(\.id))
        for entry in entries where ownIDs.contains(entry.babyID) {
            let path = "babies/\(entry.babyID)/entries/\(entry.id)"
            if entry.deleted {
                try? await delete(path: path, token: token)
            } else {
                try await put(path: path, fields: entryFields(entry), token: token)
            }
        }
    }

    // MARK: Pull

    private func pullRemote(context: ModelContext, uid: String, token: String) async throws {
        let babyDocs = try await queryBabies(uid: uid, token: token)
        for doc in babyDocs {
            guard let id = doc.docID else { continue }
            upsertBaby(doc, id: id, context: context)
            let entryDocs = try await listEntries(babyID: id, token: token)
            for e in entryDocs { upsertEntry(e, babyID: id, context: context) }
        }
    }

    private func upsertBaby(_ f: FSDoc, id: String, context: ModelContext) {
        let remoteUpdated = f.date("updatedAt") ?? .distantPast
        let existing = try? context.fetch(FetchDescriptor<Baby>(predicate: #Predicate { $0.id == id })).first
        if let baby = existing {
            if remoteUpdated > baby.updatedAt {
                baby.name = f.string("name") ?? baby.name
                if let bd = f.date("birthDate") { baby.birthDate = bd }
                baby.genderRaw = f.string("gender") ?? baby.genderRaw
                baby.ownerUID = f.string("ownerUID") ?? baby.ownerUID
                baby.memberUIDs = f.stringArray("members")
                baby.updatedAt = remoteUpdated
            } else {
                // merge membership additions regardless
                baby.memberUIDs = Array(Set(baby.memberUIDs).union(f.stringArray("members")))
            }
        } else {
            let baby = Baby(id: id,
                            name: f.string("name") ?? "Bebek",
                            birthDate: f.date("birthDate") ?? Date(),
                            gender: BabyGender(rawValue: f.string("gender") ?? "") ?? .unspecified,
                            ownerUID: f.string("ownerUID"),
                            memberUIDs: f.stringArray("members"))
            baby.updatedAt = remoteUpdated
            context.insert(baby)
        }
    }

    private func upsertEntry(_ f: FSDoc, babyID: String, context: ModelContext) {
        guard let id = f.docID else { return }
        let remoteUpdated = f.date("updatedAt") ?? .distantPast
        let remoteDeleted = f.bool("deleted") ?? false
        let existing = try? context.fetch(FetchDescriptor<LogEntry>(predicate: #Predicate { $0.id == id })).first

        if let entry = existing {
            guard remoteUpdated > entry.updatedAt else { return }
            apply(f, to: entry)
            entry.deleted = remoteDeleted
        } else {
            guard !remoteDeleted else { return }
            let type = EntryType(rawValue: f.string("type") ?? "note") ?? .note
            let entry = LogEntry(id: id, babyID: babyID, type: type, date: f.date("date") ?? Date())
            apply(f, to: entry)
            context.insert(entry)
        }
    }

    private func apply(_ f: FSDoc, to entry: LogEntry) {
        entry.typeRaw = f.string("type") ?? entry.typeRaw
        if let d = f.date("date") { entry.date = d }
        entry.endDate = f.date("endDate")
        entry.feedingTypeRaw = f.string("feedingType")
        entry.amountML = f.double("amountML")
        entry.durationMin = f.double("durationMin")
        entry.sideRaw = f.string("side")
        entry.diaperKindRaw = f.string("diaperKind")
        entry.medName = f.string("medName")
        entry.dose = f.string("dose")
        entry.temperatureC = f.double("temperatureC")
        entry.weightKg = f.double("weightKg")
        entry.heightCm = f.double("heightCm")
        entry.headCm = f.double("headCm")
        entry.vaccineName = f.string("vaccineName")
        entry.vaccineDone = f.bool("vaccineDone") ?? false
        entry.text = f.string("text")
        entry.tagsRaw = f.string("tags")
        entry.updatedAt = f.date("updatedAt") ?? entry.updatedAt
    }

    // MARK: Family sharing

    /// Creates an invite code that another caregiver can use to join this baby.
    func createInvite(babyID: String) async throws -> String {
        guard let uid = auth.uid, let token = try await auth.validToken() else {
            throw AuthError.notConfigured
        }
        let code = Self.randomCode()
        try await put(path: "invites/\(code)", fields: [
            "babyId": .string(babyID),
            "createdBy": .string(uid),
            "createdAt": .date(Date()),
        ], token: token)
        return code
    }

    /// Joins a baby via an invite code. Returns the babyId on success.
    @discardableResult
    func joinWithInvite(code: String, context: ModelContext) async throws -> String {
        guard let uid = auth.uid, let token = try await auth.validToken() else {
            throw AuthError.notConfigured
        }
        let invite = try await get(path: "invites/\(code.uppercased())", token: token)
        guard let babyID = invite.string("babyId") else { throw AuthError.server("INVITE_NOT_FOUND") }
        // Read baby, add self to members.
        let babyDoc = try await get(path: "babies/\(babyID)", token: token)
        var members = babyDoc.stringArray("members")
        if !members.contains(uid) { members.append(uid) }
        try await patch(path: "babies/\(babyID)", fields: ["members": .stringArray(members)],
                        mask: ["members"], token: token)
        // Pull the baby + entries into local store.
        upsertBaby(babyDoc, id: babyID, context: context)
        let entries = try await listEntries(babyID: babyID, token: token)
        for e in entries { upsertEntry(e, babyID: babyID, context: context) }
        try? context.save()
        return babyID
    }

    /// Deletes all cloud data owned by the user (for account deletion).
    func deleteAllCloudData(context: ModelContext) async {
        guard let uid = auth.uid, let token = try? await auth.validToken() else { return }
        let babies = (try? context.fetch(FetchDescriptor<Baby>())) ?? []
        for baby in babies where baby.ownerUID == uid {
            let entries = try? await listEntries(babyID: baby.id, token: token)
            for e in entries ?? [] {
                if let id = e.docID { try? await delete(path: "babies/\(baby.id)/entries/\(id)", token: token) }
            }
            try? await delete(path: "babies/\(baby.id)", token: token)
        }
    }

    // MARK: Field encoders

    private func babyFields(_ b: Baby) -> [String: FSValue] {
        [
            "name": .string(b.name),
            "birthDate": .date(b.birthDate),
            "gender": .string(b.genderRaw),
            "ownerUID": .string(b.ownerUID ?? ""),
            "members": .stringArray(b.memberUIDs),
            "updatedAt": .date(b.updatedAt),
            "createdAt": .date(b.createdAt),
        ]
    }

    private func entryFields(_ e: LogEntry) -> [String: FSValue] {
        var f: [String: FSValue] = [
            "type": .string(e.typeRaw),
            "date": .date(e.date),
            "vaccineDone": .bool(e.vaccineDone),
            "deleted": .bool(e.deleted),
            "updatedAt": .date(e.updatedAt),
            "createdAt": .date(e.createdAt),
        ]
        if let v = e.endDate { f["endDate"] = .date(v) }
        if let v = e.feedingTypeRaw { f["feedingType"] = .string(v) }
        if let v = e.amountML { f["amountML"] = .double(v) }
        if let v = e.durationMin { f["durationMin"] = .double(v) }
        if let v = e.sideRaw { f["side"] = .string(v) }
        if let v = e.diaperKindRaw { f["diaperKind"] = .string(v) }
        if let v = e.medName { f["medName"] = .string(v) }
        if let v = e.dose { f["dose"] = .string(v) }
        if let v = e.temperatureC { f["temperatureC"] = .double(v) }
        if let v = e.weightKg { f["weightKg"] = .double(v) }
        if let v = e.heightCm { f["heightCm"] = .double(v) }
        if let v = e.headCm { f["headCm"] = .double(v) }
        if let v = e.vaccineName { f["vaccineName"] = .string(v) }
        if let v = e.text { f["text"] = .string(v) }
        if let v = e.tagsRaw { f["tags"] = .string(v) }
        return f
    }

    // MARK: REST primitives

    private func put(path: String, fields: [String: FSValue], token: String) async throws {
        try await patch(path: path, fields: fields, mask: nil, token: token)
    }

    private func patch(path: String, fields: [String: FSValue], mask: [String]?, token: String) async throws {
        var urlString = "\(FirebaseConfig.firestoreBase)/\(path)"
        if let mask {
            let q = mask.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
            urlString += "?\(q)"
        }
        guard let url = URL(string: urlString) else { throw AuthError.network }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["fields": fields.mapValues { $0.json }]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        try await run(req)
    }

    private func delete(path: String, token: String) async throws {
        guard let url = URL(string: "\(FirebaseConfig.firestoreBase)/\(path)") else { throw AuthError.network }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        try await run(req)
    }

    private func get(path: String, token: String) async throws -> FSDoc {
        guard let url = URL(string: "\(FirebaseConfig.firestoreBase)/\(path)") else { throw AuthError.network }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return FSDoc(obj)
    }

    private func queryBabies(uid: String, token: String) async throws -> [FSDoc] {
        guard let url = URL(string: "\(FirebaseConfig.firestoreBase):runQuery") else { throw AuthError.network }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "babies"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "members"],
                        "op": "ARRAY_CONTAINS",
                        "value": ["stringValue": uid],
                    ]
                ],
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: query)
        let (data, _) = try await URLSession.shared.data(for: req)
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        return arr.compactMap { ($0["document"] as? [String: Any]).map(FSDoc.init) }
    }

    private func listEntries(babyID: String, token: String) async throws -> [FSDoc] {
        var results: [FSDoc] = []
        var pageToken: String?
        repeat {
            var urlString = "\(FirebaseConfig.firestoreBase)/babies/\(babyID)/entries?pageSize=300"
            if let pageToken { urlString += "&pageToken=\(pageToken)" }
            guard let url = URL(string: urlString) else { break }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let docs = (obj["documents"] as? [[String: Any]]) ?? []
            results.append(contentsOf: docs.map(FSDoc.init))
            pageToken = obj["nextPageToken"] as? String
        } while pageToken != nil
        return results
    }

    @discardableResult
    private func run(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = ((obj?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw AuthError.server(msg)
        }
        return data
    }

    static func randomCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

// MARK: - Firestore value helpers

enum FSValue {
    case string(String)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case stringArray([String])

    var json: [String: Any] {
        switch self {
        case .string(let s): return ["stringValue": s]
        case .double(let d): return ["doubleValue": d]
        case .bool(let b): return ["booleanValue": b]
        case .date(let d): return ["timestampValue": CloudSyncDateFormatter.string(d)]
        case .stringArray(let a):
            return ["arrayValue": ["values": a.map { ["stringValue": $0] }]]
        }
    }
}

enum CloudSyncDateFormatter {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func string(_ d: Date) -> String { iso.string(from: d) }
    static func date(_ s: String) -> Date? { iso.date(from: s) }
}

/// Lightweight reader over a Firestore document JSON object.
struct FSDoc {
    let raw: [String: Any]
    let fields: [String: Any]
    init(_ raw: [String: Any]) {
        self.raw = raw
        self.fields = (raw["fields"] as? [String: Any]) ?? [:]
    }
    /// Document ID parsed from the resource `name`.
    var docID: String? {
        guard let name = raw["name"] as? String else { return nil }
        return name.split(separator: "/").last.map(String.init)
    }
    func string(_ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }
    func double(_ key: String) -> Double? {
        guard let v = fields[key] as? [String: Any] else { return nil }
        if let d = v["doubleValue"] as? Double { return d }
        if let i = v["integerValue"] as? String { return Double(i) }
        if let d = v["doubleValue"] as? NSNumber { return d.doubleValue }
        return nil
    }
    func bool(_ key: String) -> Bool? {
        (fields[key] as? [String: Any])?["booleanValue"] as? Bool
    }
    func date(_ key: String) -> Date? {
        guard let s = (fields[key] as? [String: Any])?["timestampValue"] as? String else { return nil }
        return CloudSyncDateFormatter.date(s) ?? ISO8601DateFormatter().date(from: s)
    }
    func stringArray(_ key: String) -> [String] {
        guard let arr = ((fields[key] as? [String: Any])?["arrayValue"] as? [String: Any])?["values"] as? [[String: Any]] else { return [] }
        return arr.compactMap { $0["stringValue"] as? String }
    }
}
