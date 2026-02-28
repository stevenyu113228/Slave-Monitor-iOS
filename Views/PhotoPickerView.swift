import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    let client: TtydClient
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var uploadStatus = ""
    @State private var isUploading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Select Photos", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.blue))
                }

                if !uploadStatus.isEmpty {
                    Text(uploadStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isUploading {
                    ProgressView()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Upload Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: selectedItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await uploadPhotos(items) }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func uploadPhotos(_ items: [PhotosPickerItem]) async {
        isUploading = true
        var uploadedPaths: [String] = []
        let total = items.count
        var done = 0

        for item in items {
            uploadStatus = "Processing \(done + 1)/\(total)..."
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                done += 1
                continue
            }

            // Compress image
            guard let image = UIImage(data: data) else {
                done += 1
                continue
            }
            let compressed = compressImage(image, maxWidth: 1568, quality: 0.85)

            // Generate filename
            let name = "photo-\(Int(Date().timeIntervalSince1970))-\(done + 1).jpg"

            uploadStatus = "Uploading \(done + 1)/\(total)..."
            do {
                let result = try await appState.apiClient.uploadImage(compressed, name: name)
                if let path = result.path {
                    uploadedPaths.append(path)
                }
            } catch {
                uploadStatus = "Upload failed: \(error.localizedDescription)"
            }

            done += 1
        }

        if !uploadedPaths.isEmpty {
            // Send paths to terminal
            let pathText = uploadedPaths.joined(separator: " ")
            let bytes = Array(pathText.utf8)
            client.sendInput(bytes)

            uploadStatus = "Uploaded \(uploadedPaths.count) photo(s)"
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        }

        isUploading = false
        selectedItems = []
    }

    private func compressImage(_ image: UIImage, maxWidth: CGFloat, quality: CGFloat) -> Data {
        var size = image.size
        if size.width > maxWidth {
            let ratio = maxWidth / size.width
            size = CGSize(width: maxWidth, height: size.height * ratio)
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        return resized.jpegData(compressionQuality: quality) ?? Data()
    }
}
