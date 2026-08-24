import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PhotoViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Text("Мои фото")
                .font(.headline)
                .padding(.top, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))

                if let photo = viewModel.currentPhoto {
                    Image(nsImage: photo.image)
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

            // Временная кнопка для проверки UI
            HStack(spacing: 12) {
                Button("Добавить тестовое фото") {
                    viewModel.addTestPhoto()
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
