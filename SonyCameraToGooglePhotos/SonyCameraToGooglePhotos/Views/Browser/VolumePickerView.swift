import SwiftUI

struct VolumePickerView: View {
    @EnvironmentObject var volumeViewModel: VolumeDetectionViewModel

    var body: some View {
        HStack {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.secondary)

            if volumeViewModel.volumes.isEmpty {
                Text("No volumes detected")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Volume", selection: $volumeViewModel.selectedVolume) {
                    ForEach(volumeViewModel.volumes) { volume in
                        Text(volume.displayName)
                            .tag(Optional(volume))
                    }
                }
                .labelsHidden()
            }

            Button(action: {
                volumeViewModel.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh volumes")
        }
    }
}
