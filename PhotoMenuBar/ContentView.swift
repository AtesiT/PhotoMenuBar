import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Мои фото")
                .font(.headline)
                .padding(.top, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))

                if viewModel.isLoading {
                    ProgressView("Добавляем фото…")
                } else if let photo = viewModel.currentPhoto,
                          let nsImage = viewModel.image(for: photo) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .id(photo.id)
                        .transition(.opacity)
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
            .animation(.easeInOut(duration: 0.15), value: viewModel.currentIndex)

            HStack {
                navButton(systemName: "chevron.left", enabled: viewModel.canGoBack) {
                    viewModel.goBack()
                }

                Spacer()

                Text(counterText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                navButton(systemName: "chevron.right", enabled: viewModel.canGoForward) {
                    viewModel.goForward()
                }
            }
            .padding(.horizontal, 30)
            .background(
                Button("") { viewModel.goBack() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .opacity(0)
            )
            .background(
                Button("") { viewModel.goForward() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .opacity(0)
            )

            Divider()

            // Все три кнопки
            HStack(spacing: 10) {
                Button {
                    presentFinderPanel()
                } label: {
                    Label("Добавить", systemImage: "plus.circle")
                }
                .disabled(viewModel.isLoading)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
                .disabled(viewModel.currentPhoto == nil)
                .confirmationDialog(
                    "Удалить это фото?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Удалить", role: .destructive) {
                        viewModel.deleteCurrentPhoto()
                    }
                    Button("Отмена", role: .cancel) {}
                }
                Button("Выход") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 360, height: 420)
    }

    private var counterText: String {
        guard !viewModel.photos.isEmpty else { return "0 из 0" }
        return "\(viewModel.currentIndex + 1) из \(viewModel.photos.count)"
    }

    private func presentFinderPanel() {
        let panel = NSOpenPanel()
        panel.title = "Выберите фото"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task {
                await viewModel.addPhotos(from: urls)
            }
        }
    }

    @ViewBuilder
    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(enabled ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08))
                )
                .foregroundColor(enabled ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
