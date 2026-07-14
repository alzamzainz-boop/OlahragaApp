import SwiftUI

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
            }
            .padding(.top, 20)

            if isSearching {
                // Searching indicator
                ProgressView("Searching for nearby devices...")
                    .foregroundStyle(.secondary)

                // Peer list
                if let manager = appState.multipeerManager, !manager.foundPeers.isEmpty {
                    List(manager.foundPeers) { peer in
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.title2)
                                .foregroundStyle(.orange)

                            Text(peer.displayName)
                                .font(.body)

                            Spacer()

                            Button("Connect") {
                                manager.invite(peer.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding(.vertical, 4)
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

            // Search button
            Button {
                isSearching.toggle()
                guard let manager = appState.multipeerManager else { return }
                if isSearching {
                    manager.startAdvertising()
                    manager.startBrowsing()
                } else {
                    manager.stop()
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
}
