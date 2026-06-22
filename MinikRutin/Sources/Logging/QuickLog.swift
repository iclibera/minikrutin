import SwiftUI

enum QuickLogTarget: String, Identifiable {
    case menu, feeding, sleep, diaper, medicine, pumping, note
    var id: String { rawValue }
}

/// Routes the quick-log sheet to the menu or directly to a form.
struct QuickLogSheet: View {
    let baby: Baby
    let target: QuickLogTarget
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch target {
                case .menu: QuickLogMenu(baby: baby, onClose: { dismiss() })
                case .feeding: FeedingFormView(baby: baby, onClose: { dismiss() })
                case .sleep: SleepFormView(baby: baby, onClose: { dismiss() })
                case .diaper: DiaperFormView(baby: baby, onClose: { dismiss() })
                case .medicine: MedicineFormView(baby: baby, onClose: { dismiss() })
                case .pumping: PumpingFormView(baby: baby, onClose: { dismiss() })
                case .note: NoteFormView(baby: baby, onClose: { dismiss() })
                }
            }
        }
    }
}

/// The "Hızlı kayıt" screen — tek dokunuşla en sık kullanılan kayıt tipleri.
struct QuickLogMenu: View {
    let baby: Baby
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                NavigationLink { FeedingFormView(baby: baby, onClose: onClose) } label: {
                    QuickActionRow(title: "Beslenme", subtitle: "Anne sütü / mama", icon: "drop.fill", tint: Theme.brand)
                }
                NavigationLink { SleepFormView(baby: baby, onClose: onClose) } label: {
                    QuickActionRow(title: "Uyku", subtitle: "Başladı / uyandı", icon: "moon.stars.fill", tint: Color(hex: 0x6C7BD1))
                }
                NavigationLink { DiaperFormView(baby: baby, onClose: onClose) } label: {
                    QuickActionRow(title: "Bez", subtitle: "Islak / kaka", icon: "leaf.fill", tint: Color(hex: 0xCFA15A))
                }
                NavigationLink { MedicineFormView(baby: baby, onClose: onClose) } label: {
                    QuickActionRow(title: "İlaç & ateş", subtitle: "Doz / derece", icon: "cross.case.fill", tint: Theme.danger)
                }
                NavigationLink { PumpingFormView(baby: baby, onClose: onClose) } label: {
                    QuickActionRow(title: "Süt sağma", subtitle: "ml ve saat", icon: "waterbottle.fill", tint: Color(hex: 0x4FA3C7))
                }
                NavigationLink { NoteFormView(baby: baby, onClose: onClose) } label: {
                    QuickActionRow(title: "Not", subtitle: "Kusma, gaz, huzursuzluk", icon: "note.text", tint: Color(hex: 0x8E8E93))
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Hızlı kayıt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Kapat", action: onClose)
            }
        }
    }
}
