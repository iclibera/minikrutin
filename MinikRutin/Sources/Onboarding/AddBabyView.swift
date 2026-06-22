import SwiftUI
import PhotosUI

struct AddBabyView: View {
    let isOnboarding: Bool
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var birthDate = Date()
    @State private var gender: BabyGender = .unspecified
    @State private var photoItem: PhotosPickerItem?
    @State private var photoFileName: String?
    @State private var pickedImage: UIImage?
    @State private var addVitaminReminder = true

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack {
                            if let img = pickedImage {
                                Image(uiImage: img).resizable().scaledToFill()
                            } else {
                                Circle().fill(Theme.blush)
                                Image(systemName: "camera.fill").foregroundStyle(.white).font(.title3)
                            }
                        }
                        .frame(width: 92, height: 92).clipShape(Circle())
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section("Bebek bilgileri") {
                TextField("Ad", text: $name)
                DatePicker("Doğum tarihi", selection: $birthDate, in: ...Date(), displayedComponents: .date)
            }
            Section("Cinsiyet (isteğe bağlı)") {
                Picker("Cinsiyet", selection: $gender) {
                    Text("Kız").tag(BabyGender.girl)
                    Text("Erkek").tag(BabyGender.boy)
                    Text("—").tag(BabyGender.unspecified)
                }.pickerStyle(.segmented)
            }
            if isOnboarding {
                Section {
                    Toggle("D vitamini hatırlatması (20:00)", isOn: $addVitaminReminder)
                } footer: {
                    Text("Aşı takvimi ve ilaç kullanımı için doktorunuza danışın. İstediğiniz zaman Ayarlar'dan değiştirebilirsiniz.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(isOnboarding ? "Bebeğini ekle" : "Yeni bebek")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Kaydet", systemImage: "checkmark", enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, action: save)
                .padding(16).background(.ultraThinMaterial)
        }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pickedImage = image
                    photoFileName = ImageStore.save(image)
                }
            }
        }
    }

    private func save() {
        let baby = env.addBaby(name: name.trimmingCharacters(in: .whitespaces),
                               birthDate: birthDate, gender: gender, photoFileName: photoFileName)
        if isOnboarding && addVitaminReminder {
            let reminder = ReminderItem(babyID: baby.id, title: "D vitamini", kind: .vitaminD, hour: 20, minute: 0)
            env.modelContext.insert(reminder)
            env.save()
            Task {
                if await env.notifications.requestAuthorization() {
                    env.notifications.sync(reminder)
                }
            }
        }
        if !isOnboarding { dismiss() }
    }
}
