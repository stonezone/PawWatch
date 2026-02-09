#if os(iOS)
import SwiftUI
import PhotosUI
import UIKit

/// Pet profile card with avatar and name editing
@MainActor
struct PetProfileCard: View {
    @Environment(PetLocationManager.self) private var locationManager
    @Environment(PetProfileStore.self) private var petProfileStore

    @State private var selectedPetPhotoItem: PhotosPickerItem?
    @State private var petPhotoLoadTask: Task<Void, Never>?
    @State private var petPhotoError: String?
    @State private var showPhotoUploadSuccess = false

    @Binding var showFullScreenPhoto: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 88, height: 88)

                    if let avatarImage = petAvatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                            )
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.largeTitle.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if showPhotoUploadSuccess {
                        Circle()
                            .fill(.green.gradient)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onTapGesture {
                    if petAvatarImage != nil {
                        showFullScreenPhoto = true
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        "Pet name",
                        text: Binding(
                            get: { petProfileStore.profile.name },
                            set: { petProfileStore.profile.name = $0 }
                        )
                    )
                    .textInputAutocapitalization(.words)

                    TextField(
                        "Pet type (Dog, Cat, etc.)",
                        text: Binding(
                            get: { petProfileStore.profile.type },
                            set: { petProfileStore.profile.type = $0 }
                        )
                    )
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.secondary)
                }
            }

            PhotosPicker(selection: $selectedPetPhotoItem, matching: .images) {
                Label("Choose pet photo", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .onChange(of: selectedPetPhotoItem) { _, newItem in
                petPhotoLoadTask?.cancel()
                petPhotoError = nil

                guard let newItem else { return }
                petPhotoLoadTask = Task { @MainActor in
                    do {
                        guard let imageData = try await newItem.loadTransferable(type: Data.self) else {
                            petPhotoError = "Unable to load photo."
                            return
                        }
                        guard let image = UIImage(data: imageData) else {
                            petPhotoError = "Unsupported image format."
                            return
                        }
                        guard let avatarData = renderAvatarPNG(from: image, side: 128) else {
                            petPhotoError = "Unable to process photo."
                            return
                        }
                        petProfileStore.profile.avatarPNGData = avatarData

                        // Show success animation
                        withAnimation(Animations.quick) {
                            showPhotoUploadSuccess = true
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation {
                                showPhotoUploadSuccess = false
                            }
                        }
                    } catch {
                        petPhotoError = "Photo error: \(error.localizedDescription)"
                    }
                }
            }

            Button {
                locationManager.pingWatch()
            } label: {
                Label("Ping watch", systemImage: "bell")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .disabled(!locationManager.isWatchReachable)

            if petProfileStore.profile.avatarPNGData != nil {
                Button(role: .destructive) {
                    petProfileStore.clearAvatar()
                } label: {
                    Label("Remove photo", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
            }

            if let petPhotoError {
                Text(petPhotoError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else {
                Text("Pet profile syncs to your watch when it's reachable, otherwise it queues for delivery.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var petAvatarImage: UIImage? {
        guard let data = petProfileStore.profile.avatarPNGData else { return nil }
        return UIImage(data: data)
    }

    private func renderAvatarPNG(from image: UIImage, side: CGFloat) -> Data? {
        let targetSize = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (side - scaledSize.width) / 2, y: (side - scaledSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        return rendered.pngData()
    }
}

#endif
