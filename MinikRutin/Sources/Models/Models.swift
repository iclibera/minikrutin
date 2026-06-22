import Foundation
import SwiftData

// MARK: - Enums

enum BabyGender: String, Codable, CaseIterable, Identifiable {
    case unspecified, girl, boy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .unspecified: return "Belirtmek istemiyorum"
        case .girl: return "Kız"
        case .boy: return "Erkek"
        }
    }
}

/// All loggable event kinds. Stored in a single unified `LogEntry` table so
/// that aggregation and Firestore sync stay simple.
enum EntryType: String, Codable, CaseIterable, Identifiable {
    case feeding, sleep, diaper, medicine, pumping, note, growth, vaccine
    var id: String { rawValue }

    var title: String {
        switch self {
        case .feeding: return "Beslenme"
        case .sleep: return "Uyku"
        case .diaper: return "Bez"
        case .medicine: return "İlaç & ateş"
        case .pumping: return "Süt sağma"
        case .note: return "Not"
        case .growth: return "Büyüme"
        case .vaccine: return "Aşı / kontrol"
        }
    }

    var icon: String {
        switch self {
        case .feeding: return "drop.fill"
        case .sleep: return "moon.stars.fill"
        case .diaper: return "leaf.fill"
        case .medicine: return "cross.case.fill"
        case .pumping: return "waterbottle.fill"
        case .note: return "note.text"
        case .growth: return "ruler.fill"
        case .vaccine: return "syringe.fill"
        }
    }
}

enum FeedingType: String, Codable, CaseIterable, Identifiable {
    case breastMilk, formula, nursing
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breastMilk: return "Anne sütü"
        case .formula: return "Mama"
        case .nursing: return "Emzirme"
        }
    }
}

enum NursingSide: String, Codable, CaseIterable, Identifiable {
    case left, right, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .left: return "Sol"
        case .right: return "Sağ"
        case .both: return "Her ikisi"
        }
    }
}

enum DiaperKind: String, Codable, CaseIterable, Identifiable {
    case wet, dirty, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .wet: return "Islak"
        case .dirty: return "Kaka"
        case .both: return "İkisi birden"
        }
    }
}

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case vitaminD, iron, medicine, checkup, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .vitaminD: return "D vitamini"
        case .iron: return "Demir damlası"
        case .medicine: return "İlaç"
        case .checkup: return "Doktor kontrolü"
        case .custom: return "Özel hatırlatma"
        }
    }
    var icon: String {
        switch self {
        case .vitaminD: return "sun.max.fill"
        case .iron: return "drop.fill"
        case .medicine: return "pills.fill"
        case .checkup: return "stethoscope"
        case .custom: return "bell.fill"
        }
    }
}

// MARK: - Baby

@Model
final class Baby {
    @Attribute(.unique) var id: String
    var name: String
    var birthDate: Date
    var genderRaw: String
    var photoFileName: String?
    var ownerUID: String?
    var memberUIDs: [String]
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         birthDate: Date,
         gender: BabyGender = .unspecified,
         photoFileName: String? = nil,
         ownerUID: String? = nil,
         memberUIDs: [String] = []) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.genderRaw = gender.rawValue
        self.photoFileName = photoFileName
        self.ownerUID = ownerUID
        self.memberUIDs = memberUIDs
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var gender: BabyGender {
        get { BabyGender(rawValue: genderRaw) ?? .unspecified }
        set { genderRaw = newValue.rawValue }
    }
}

// MARK: - Log entry (unified)

@Model
final class LogEntry {
    @Attribute(.unique) var id: String
    var babyID: String
    var typeRaw: String
    var date: Date
    var endDate: Date?

    // Feeding
    var feedingTypeRaw: String?
    var amountML: Double?
    var durationMin: Double?
    var sideRaw: String?

    // Diaper
    var diaperKindRaw: String?

    // Medicine / fever
    var medName: String?
    var dose: String?
    var temperatureC: Double?

    // Growth
    var weightKg: Double?
    var heightCm: Double?
    var headCm: Double?

    // Vaccine / checkup
    var vaccineName: String?
    var vaccineDone: Bool

    // Free text (notes, vaccine notes) + tags
    var text: String?
    var tagsRaw: String?

    var createdAt: Date
    var updatedAt: Date
    var deleted: Bool

    init(id: String = UUID().uuidString,
         babyID: String,
         type: EntryType,
         date: Date = Date()) {
        self.id = id
        self.babyID = babyID
        self.typeRaw = type.rawValue
        self.date = date
        self.vaccineDone = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deleted = false
    }

    var type: EntryType {
        get { EntryType(rawValue: typeRaw) ?? .note }
        set { typeRaw = newValue.rawValue }
    }
    var feedingType: FeedingType? {
        get { feedingTypeRaw.flatMap(FeedingType.init) }
        set { feedingTypeRaw = newValue?.rawValue }
    }
    var side: NursingSide? {
        get { sideRaw.flatMap(NursingSide.init) }
        set { sideRaw = newValue?.rawValue }
    }
    var diaperKind: DiaperKind? {
        get { diaperKindRaw.flatMap(DiaperKind.init) }
        set { diaperKindRaw = newValue?.rawValue }
    }
    var tags: [String] {
        get { (tagsRaw ?? "").split(separator: ",").map { String($0) }.filter { !$0.isEmpty } }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    /// Sleep duration in minutes (uses now for ongoing sleeps).
    var sleepMinutes: Double {
        guard type == .sleep else { return 0 }
        let end = endDate ?? Date()
        return max(0, end.timeIntervalSince(date) / 60)
    }
}

// MARK: - Memory (local-only photo)

@Model
final class Memory {
    @Attribute(.unique) var id: String
    var babyID: String
    var date: Date
    var photoFileName: String
    var caption: String
    var createdAt: Date

    init(id: String = UUID().uuidString,
         babyID: String,
         date: Date = Date(),
         photoFileName: String,
         caption: String = "") {
        self.id = id
        self.babyID = babyID
        self.date = date
        self.photoFileName = photoFileName
        self.caption = caption
        self.createdAt = Date()
    }
}

// MARK: - Reminder

@Model
final class ReminderItem {
    @Attribute(.unique) var id: String
    var babyID: String
    var title: String
    var kindRaw: String
    var hour: Int
    var minute: Int
    var repeatsDaily: Bool
    var enabled: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString,
         babyID: String,
         title: String,
         kind: ReminderKind = .custom,
         hour: Int = 20,
         minute: Int = 0,
         repeatsDaily: Bool = true,
         enabled: Bool = true) {
        self.id = id
        self.babyID = babyID
        self.title = title
        self.kindRaw = kind.rawValue
        self.hour = hour
        self.minute = minute
        self.repeatsDaily = repeatsDaily
        self.enabled = enabled
        self.createdAt = Date()
    }

    var kind: ReminderKind {
        get { ReminderKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }
    var timeLabel: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
