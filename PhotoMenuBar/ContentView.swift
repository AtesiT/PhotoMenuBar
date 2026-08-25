import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(spacing: 12) {
            Text("Мои фото")
                .font(.headline)
                .padding(.top, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))

                if let photo = viewModel.currentPhoto,
                   let nsImage = viewModel.image(for: photo) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Нет добавленных фото")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 240)
            .padding(.horizontal)

            HStack {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!viewModel.canGoBack)

                Spacer()

                Text(counterText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: viewModel.goForward) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!viewModel.canGoForward)
            }
            .padding(.horizontal, 30)

            Divider()

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Добавить фото", systemImage: "plus.circle")
                }
                .onChange(of: selectedItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    Task {
                        await viewModel.addPhotos(from: newItems)
                        selectedItems = []
                    }
                }

                Button(role: .destructive) {
                    viewModel.deleteCurrentPhoto()
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
                .disabled(viewModel.currentPhoto == nil)
            }
            .padding(.bottom, 12)

            Divider()

            Button("Выход") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 360, height: 420)
    }

    private var counterText: String {
        guard !viewModel.photos.isEmpty else { return "0 из 0" }
        return "\(viewModel.currentIndex + 1) из \(viewModel.photos.count)"
    }
}
