import SwiftUI
import MultipeerConnectivity

struct NearbyRadarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        // Akses langsung — bukan computed property — supaya SwiftUI bisa track
        let ni = appState.niManager

        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {

                // Partner name
                Text(appState.multipeerManager?.connectedPeer?.displayName ?? "Partner")
                    .font(.title2)
                    .foregroundStyle(.orange)

                // Arrow + Radar Ring
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                        .frame(width: 280, height: 280)

                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                        .frame(width: 180, height: 180)

                    radarContent(ni: ni)
                }

                // Distance
                distanceDisplay(ni: ni)

                // Room formation hint
                if let distance = ni.distance, distance < 2.0 {
                    Text("Close enough to start!")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(20)
                }

                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // Navigasi balik — cleanup dilakukan di onDisappear
                    appState.navigationPath.removeAll()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.orange)
                }
            }
        }
        .onChange(of: appState.currentRoom) { _, newRoom in
            // Kalau room terbentuk, jangan cleanup
            if newRoom != nil {
                print("[Radar] Room formed, staying connected")
            }
        }
        .onDisappear {
            // Cleanup HANYA kalau tidak sedang forming room
            // Kalau room != nil, berarti navigasi otomatis, jangan cleanup
            if appState.currentRoom == nil {
                appState.fullCleanup()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func radarContent(ni: NearbyInteractionManager) -> some View {
        if ni.isSessionActive {
            if ni.direction != nil {
                // Arrow pointing to partner (UWB available)
                Image(systemName: "arrow.up")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(ni.arrowAngleDegrees))
                    .animation(.smooth(duration: 0.3), value: ni.arrowAngleDegrees)
            } else if ni.peerIsOutOfRange {
                // Out of range
                Image(systemName: "wifi.slash")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange.opacity(0.5))
            } else {
                // Session active but no direction (device has no UWB chip)
                Image(systemName: "location.circle")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange.opacity(0.5))
            }
        } else if let error = ni.errorMessage {
            // Error — tap to retry
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .onTapGesture {
                appState.niManager.reset()
            }
        } else {
            // Waiting for token exchange to complete
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.orange)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func distanceDisplay(ni: NearbyInteractionManager) -> some View {
        if ni.peerIsOutOfRange {
            Text("Partner out of range")
                .font(.headline)
                .foregroundStyle(.orange.opacity(0.7))
        } else if let distance = ni.distance {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", distance))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("meters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview Helpers

#Preview("Radar - Connecting") {
    RadarPreview(state: .connecting)
}

#Preview("Radar - Active with Direction") {
    RadarPreview(state: .activeWithDirection)
}

#Preview("Radar - Active no UWB") {
    RadarPreview(state: .activeNoDirection)
}

#Preview("Radar - Error") {
    RadarPreview(state: .error)
}

#Preview("Radar - Out of Range") {
    RadarPreview(state: .outOfRange)
}

// MARK: - Preview Implementation

enum RadarPreviewState {
    case connecting, activeWithDirection, activeNoDirection, error, outOfRange
}

struct RadarPreview: View {
    let state: RadarPreviewState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Text("TestUser's Partner")
                    .font(.title2)
                    .foregroundStyle(.orange)

                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                        .frame(width: 280, height: 280)

                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                        .frame(width: 180, height: 180)

                    radarContent
                }

                distanceDisplay

                if shouldShowCloseEnough {
                    Text("Close enough to start!")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(20)
                }

                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var radarContent: some View {
        switch state {
        case .connecting:
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.orange)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .activeWithDirection:
            Image(systemName: "arrow.up")
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(.orange)
                .rotationEffect(.degrees(-45))
                .animation(.smooth(duration: 0.3), value: -45)

        case .activeNoDirection:
            Image(systemName: "location.circle")
                .font(.system(size: 50))
                .foregroundStyle(.orange.opacity(0.5))

        case .error:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text("Session failed. Tap to retry.")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

        case .outOfRange:
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundStyle(.orange.opacity(0.5))
        }
    }

    @ViewBuilder
    private var distanceDisplay: some View {
        switch state {
        case .outOfRange:
            Text("Partner out of range")
                .font(.headline)
                .foregroundStyle(.orange.opacity(0.7))

        case .activeWithDirection, .activeNoDirection:
            VStack(spacing: 4) {
                Text(state == .activeWithDirection ? "1.5" : "2.0")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("meters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        default:
            EmptyView()
        }
    }

    private var shouldShowCloseEnough: Bool {
        state == .activeWithDirection || state == .activeNoDirection
    }
}
