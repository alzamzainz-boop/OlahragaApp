import SwiftUI

struct RoomFormedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("Workout Room Ready!")
                .font(.largeTitle.bold())

            if let room = appState.currentRoom {
                VStack(spacing: 8) {
                    Text("Partner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(room.partnerName)
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }

            Button("Start Workout") {
                // Placeholder for future workout logic
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)

            Spacer()
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
