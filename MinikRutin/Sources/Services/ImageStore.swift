import UIKit

/// Stores baby photos locally in the app's Documents directory. Photos stay
/// on-device (not synced to the cloud) to keep sensitive imagery private.
enum ImageStore {
    private static var dir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    static func save(_ image: UIImage) -> String? {
        let name = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: dir.appendingPathComponent(name))
            return name
        } catch { return nil }
    }

    static func save(data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return save(image)
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(name).path)
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
    }
}
