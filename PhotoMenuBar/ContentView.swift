import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    @State private var isHoveringLeft = false
    @State private var isHoveringRight = false

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            imageContent

            navigationOverlay

            VStack {
                Spacer()
                if !viewModel.photos.isEmpty {
                    Text(counterText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(width: 360, height: 320)
        // Для поддержки стрелок клавиатуры
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
    }

    @ViewBuilder
    private var imageContent: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if let photo = viewModel.currentPhoto,
                  let nsImage = viewModel.image(for: photo) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(20)
                .id(photo.id)
                .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Нет добавленных фото")
                    .foregroundColor(.secondary)
                Text("ПКМ по иконке в меню → «Добавить фото»")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    private var navigationOverlay: some View {
        HStack(spacing: 0) {
            navZone(isHovering: $isHoveringLeft, enabled: viewModel.canGoBack, icon: "chevron.left") {
                viewModel.goBack()
            }

            // Центральная зона не реагирует на клик, чтобы не мешать просмотру
            Color.clear
                .frame(width: 100)
                .allowsHitTesting(false)

            navZone(isHovering: $isHoveringRight, enabled: viewModel.canGoForward, icon: "chevron.right") {
                viewModel.goForward()
            }
        }
    }

    @ViewBuilder
    private func navZone(
        isHovering: Binding<Bool>,
        enabled: Bool,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.clear

            if enabled {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.4)))
                    .opacity(isHovering.wrappedValue ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering.wrappedValue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if enabled { action() }
        }
        .onHover { hovering in
            isHovering.wrappedValue = hovering && enabled
        }
    }

    private var counterText: String {
        "\(viewModel.currentIndex + 1) из \(viewModel.photos.count)"
    }
}
