import SwiftUI
import MultipeerConnectivity

struct DiscoveryView: View {
    @Environment(AppState.self) private var appState
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 4) {
                Text("Find Workout Partner")
                    .font(.title.bold())
                Text("You: \(appState.userName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let mgr = appState.multipeerManager, mgr.isAdvertising {
                    Label("Discoverable", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.top, 20)

            if isSearching {
                ProgressView("Searching for nearby devices...")
                    .foregroundStyle(.secondary)

                if let manager = appState.multipeerManager, !manager.foundPeers.isEmpty {
                    List(manager.foundPeers) { peer in
                        peerRow(peer: peer, manager: manager)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                } else {
                    Spacer()
                    Text("No devices found yet")
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.opacity(0.5))
                Text("Press the button to start searching")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                isSearching.toggle()
                guard let manager = appState.multipeerManager else { return }
                if isSearching {
                    manager.startBrowsing()
                } else {
                    manager.stopSearching()
                }
            } label: {
                Label(isSearching ? "Stop Searching" : "Search Nearby",
                      systemImage: isSearching ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private func peerRow(peer: PeerInfo, manager: MultipeerManager) -> some View {
        let isInvited = manager.invitedPeer == peer.id

        HStack {
            Image(systemName: "person.circle")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(peer.displayName)
                    .font(.body)
                if isInvited {
                    Text("Waiting for response...")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Button {
                manager.invite(peer.id)
            } label: {
                if isInvited {
                    ProgressView()
                        .tint(.orange)
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isInvited)
        }
        .padding(.vertical, 4)
    }
}
