import SwiftUI
import SwiftData
import PhotosUI

struct MemoriesView: View {
    let baby: Baby
    @EnvironmentObject var env: AppEnvironment
    @Query private var memories: [Memory]
    @State private var photoItem: PhotosPickerItem?

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _memories = Query(filter: #Predicate<Memory> { $0.babyID == id }, sort: \.date, order: .reverse)
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Fotoğraflar yalnızca bu cihazda saklanır ve buluta gönderilmez.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)

                if memories.isEmpty {
                    Card { EmptyHint(icon: "photo.on.rectangle.angled", title: "Anı yok", message: "İlk fotoğrafınızı ekleyin.") }
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(memories) { memory in
                            MemoryCell(memory: memory) { env.modelContext.delete(memory); ImageStore.delete(memory.photoFileName); env.save() }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Anılar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $photoItem, matching: .images) { Image(systemName: "plus") }
            }
        }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let name = ImageStore.save(data: data) {
                    let memory = Memory(babyID: baby.id, photoFileName: name)
                    env.modelContext.insert(memory)
                    env.save()
                }
                photoItem = nil
            }
        }
    }
}

private struct MemoryCell: View {
    let memory: Memory
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = ImageStore.load(memory.photoFileName) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.surfaceAlt
            }
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
            Text(Fmt.shortDate(memory.date)).font(.caption2.weight(.semibold)).foregroundStyle(.white).padding(8)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu { Button(role: .destructive, action: onDelete) { Label("Sil", systemImage: "trash") } }
    }
}
