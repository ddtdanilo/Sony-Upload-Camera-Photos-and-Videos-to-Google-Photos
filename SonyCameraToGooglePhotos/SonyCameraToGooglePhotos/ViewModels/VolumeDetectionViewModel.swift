import Foundation
import Combine

@MainActor
final class VolumeDetectionViewModel: ObservableObject {
    @Published var volumes: [CameraVolume] = []
    @Published var selectedVolume: CameraVolume?

    private let volumeService: VolumeDetectionService
    private var cancellables = Set<AnyCancellable>()

    init(volumeService: VolumeDetectionService = VolumeDetectionService()) {
        self.volumeService = volumeService

        volumeService.$mountedVolumes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumes in
                self?.volumes = volumes
                // Auto-select first Sony volume if nothing is selected
                if self?.selectedVolume == nil {
                    self?.selectedVolume = volumes.first { $0.isSonyCamera } ?? volumes.first
                }
                // Clear selection if the selected volume was unmounted
                if let selected = self?.selectedVolume,
                   !volumes.contains(where: { $0.url == selected.url }) {
                    self?.selectedVolume = volumes.first { $0.isSonyCamera } ?? volumes.first
                }
            }
            .store(in: &cancellables)
    }

    func refresh() {
        volumeService.scanForVolumes()
    }
}
