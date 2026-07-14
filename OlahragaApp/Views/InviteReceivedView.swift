import SwiftUI
import MultipeerConnectivity

struct InviteReceivedView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("\(appState.multipeerManager?.pendingInvitingPeer?.displayName ?? "Someone") wants to work out with you!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Text("Location Sharing")
                    .font(.headline)

                Text("Accepting will share your approximate location (distance and direction) with this device in real-time during the workout session. Your location is not stored anywhere.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)

            HStack(spacing: 20) {
                Button {
                    appState.multipeerManager?.declineInvitation()
                    dismiss()
                } label: {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    appState.multipeerManager?.acceptInvitation()
                    dismiss()
                } label: {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
            }
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}
