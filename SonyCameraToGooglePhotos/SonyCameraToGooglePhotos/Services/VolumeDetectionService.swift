import Foundation
import AppKit
import Combine

final class VolumeDetectionService: ObservableObject {
    @Published var mountedVolumes: [CameraVolume] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        // Get initial volumes
        scanForVolumes()

        // Watch for mount events
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didMountNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleVolumeMount(notification)
            }
            .store(in: &cancellables)

        // Watch for unmount events
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didUnmountNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleVolumeUnmount(notification)
            }
            .store(in: &cancellables)
    }

    func stopMonitoring() {
        cancellables.removeAll()
    }

    func scanForVolumes() {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsLocalKey]
        guard let volumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return }

        mountedVolumes = volumeURLs.compactMap { url -> CameraVolume? in
            guard let resourceValues = try? url.resourceValues(forKeys: Set(keys)),
                  resourceValues.volumeIsRemovable == true else {
                return nil
            }
            let volume = CameraVolume(url: url)
            return volume
        }
    }

    private func handleVolumeMount(_ notification: Notification) {
        guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            return
        }

        let volume = CameraVolume(url: url)
        if !mountedVolumes.contains(where: { $0.url == url }) {
            mountedVolumes.append(volume)
        }
    }

    private func handleVolumeUnmount(_ notification: Notification) {
        guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
            return
        }
        mountedVolumes.removeAll { $0.url == url }
    }
}
