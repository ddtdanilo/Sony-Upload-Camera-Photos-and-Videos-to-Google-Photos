import Foundation

struct CameraVolume: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let isSonyCamera: Bool

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.isSonyCamera = CameraVolume.detectSonyStructure(at: url)
    }

    var displayName: String {
        if isSonyCamera {
            return "\(name) (Sony)"
        }
        return name
    }

    /// Check if the volume has Sony camera folder structure
    private static func detectSonyStructure(at url: URL) -> Bool {
        let dcimURL = url.appendingPathComponent("DCIM")
        let privateURL = url.appendingPathComponent("PRIVATE/M4ROOT")
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: dcimURL.path)
            || fileManager.fileExists(atPath: privateURL.path)
    }
}
