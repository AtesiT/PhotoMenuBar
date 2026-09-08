import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    @EnvironmentObject var sizeManager: WindowSizeManager

    @State private var isHoveringLeft = false
    @State private var isHoveringRight = false
    @State private var isHoveringResize = false
    @State private var lastDragTranslation: CGSize = .zero

    private let edgeZoneWidth: CGFloat = 60

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            WindowDragArea()

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
                        .allowsHitTesting(false)
                }
            }

            resizeHandle
        }
        .frame(width: sizeManager.currentSize.width, height: sizeManager.currentSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
        )
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
                .allowsHitTesting(false)
        } else if let photo = viewModel.currentPhoto,
                  let nsImage = viewModel.image(for: photo) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(20)
                .id(photo.id)
                .transition(.opacity)
                .allowsHitTesting(false)
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
            .allowsHitTesting(false)
        }
    }

    private var navigationOverlay: some View {
        HStack(spacing: 0) {
            navZone(isHovering: $isHoveringLeft, enabled: viewModel.canGoBack, icon: "chevron.left") {
                viewModel.goBack()
            }
            .frame(width: edgeZoneWidth)

            Color.clear
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            navZone(isHovering: $isHoveringRight, enabled: viewModel.canGoForward, icon: "chevron.right") {
                viewModel.goForward()
            }
            .frame(width: edgeZoneWidth)
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
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if enabled { action() }
        }
        .onHover { hovering in
            isHovering.wrappedValue = hovering && enabled
        }
    }

    private var resizeHandle: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .opacity(isHoveringResize ? 0.9 : 0.4)
                    .padding(8)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringResize = hovering
                        if hovering {
                            NSCursor.crosshair.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                let deltaWidth = value.translation.width - lastDragTranslation.width
                                let deltaHeight = value.translation.height - lastDragTranslation.height
                                sizeManager.updateSize(deltaWidth: deltaWidth, deltaHeight: deltaHeight)
                                lastDragTranslation = value.translation
                            }
                            .onEnded { _ in
                                lastDragTranslation = .zero
                                sizeManager.commitSize()
                            }
                    )
            }
        }
    }

    private var counterText: String {
        "\(viewModel.currentIndex + 1) из \(viewModel.photos.count)"
    }
}
