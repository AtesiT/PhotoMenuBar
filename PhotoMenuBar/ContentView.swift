import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Photo Manager")
                .font(.headline)

            Text("Здесь будет управление фото")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            Button("Выход") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 360, height: 420)
    }
}
