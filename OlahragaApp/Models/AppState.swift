import Foundation
import MultipeerConnectivity
import SwiftUI

enum AppRoute: Hashable {
    case discovery
    case radar
    case room
}

@Observable
final class AppState {
    var navigationPath: [AppRoute] = []
    var currentRoom: RoomSession?

    @ObservationIgnored
    @AppStorage("userName") var userName: String = ""

    var multipeerManager: MultipeerManager?
    let niManager = NearbyInteractionManager()

    // Token exchange state
    private var hasSentOwnToken = false
    private var pendingPeerToken: Data?
    private var hasReceivedPeerToken = false
    private var hasSentTokenACK = false

    var hasCompletedOnboarding: Bool {
        !userName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Forwarded untuk SwiftUI observation reliability
    var pendingInvitingPeer: MCPeerID? {
        multipeerManager?.pendingInvitingPeer
    }

    func setupMultipeerManager() {
        guard !userName.isEmpty else { return }

        // Reset state
        hasSentOwnToken = false
        pendingPeerToken = nil
        hasReceivedPeerToken = false
        hasSentTokenACK = false

        let manager = MultipeerManager(customDisplayName: userName)
        self.multipeerManager = manager

        manager.onDataReceived = { [weak self] type, payload, peerID in
            guard let self else { return }
            if type == .niDiscoveryToken {
                self.handlePeerTokenReceived(payload)
            } else if type == .niTokenACK {
                self.handlePeerACK()
            }
        }

        manager.onPeerConnected = { [weak self] _ in
            guard let self else { return }
            // Reset state on new connection
            self.hasSentOwnToken = false
            self.pendingPeerToken = nil
            self.hasReceivedPeerToken = false
            self.hasSentTokenACK = false
            self.navigationPath.append(.radar)
            // Send our token
            self.sendLocalNIToken()
        }

        niManager.onProximityUpdate = { [weak self] distance in
            guard let self, distance < 2.0, self.currentRoom == nil else { return }
            let partnerName = self.multipeerManager?.connectedPeer?.displayName ?? "Partner"
            self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
            self.navigationPath.append(.room)
        }

        manager.onPeerDisconnected = { [weak self] in
            guard let self else { return }
            // Reset token exchange state
            self.hasSentOwnToken = false
            self.pendingPeerToken = nil
            self.hasReceivedPeerToken = false
            self.hasSentTokenACK = false
            self.currentRoom = nil
            self.navigationPath.removeAll()
        }
    }

    // MARK: - Token Exchange Handshake

    private func sendLocalNIToken() {
        guard multipeerManager?.connectedPeer != nil else {
            print("[AppState] Skipping token send: no connected peer")
            return
        }
        guard !hasSentOwnToken else {
            print("[AppState] Already sent own token")
            return
        }
        guard let tokenData = niManager.localTokenData() else { return }

        let envelope = MultipeerMessage(type: .niDiscoveryToken, payload: tokenData)
        if let encoded = try? JSONEncoder().encode(envelope) {
            multipeerManager?.sendData(encoded)
            hasSentOwnToken = true
            print("[AppState] Sent local NI token")
        }

        // Try to configure if we already have peer's token
        tryConfigureIfReady()
    }

    private func handlePeerTokenReceived(_ data: Data) {
        print("[AppState] Handling peer token")
        pendingPeerToken = data
        hasReceivedPeerToken = true

        // Send ACK immediately so peer knows we received their token
        sendTokenACK()

        // Try to configure
        tryConfigureIfReady()
    }

    private func sendTokenACK() {
        guard multipeerManager?.connectedPeer != nil, !hasSentTokenACK else { return }
        let envelope = MultipeerMessage(type: .niTokenACK, payload: Data())
        if let encoded = try? JSONEncoder().encode(envelope) {
            multipeerManager?.sendData(encoded)
            hasSentTokenACK = true
            print("[AppState] Sent token ACK")
        }
    }

    private func handlePeerACK() {
        print("[AppState] Peer acknowledged our token")
        // We know peer has our token, they're ready
        tryConfigureIfReady()
    }

    private func tryConfigureIfReady() {
        // Configure NI session only when BOTH conditions are met:
        // 1. We've sent our token
        // 2. We've received peer's token
        guard hasSentOwnToken, hasReceivedPeerToken else {
            print("[AppState] Not ready to configure: sent=\(hasSentOwnToken), received=\(hasReceivedPeerToken)")
            return
        }
        guard let peerTokenData = pendingPeerToken else {
            print("[AppState] No peer token data")
            return
        }

        print("[AppState] Both tokens exchanged, configuring NI session")
        niManager.handleReceivedToken(peerTokenData)
    }

    /// Single entry point untuk cleanup. Dipanggil dari View.
    /// idempotent — aman dipanggil berkali-kali.
    func fullCleanup() {
        // 1. Reset NI session (ini akan invalidate dan buat session baru)
        niManager.reset()

        // 2. Disconnect Multipeer (callback onPeerDisconnected hanya clear state, tidak reset NI)
        multipeerManager?.disconnect()

        // 3. Clear room state
        currentRoom = nil
        navigationPath.removeAll()

        print("[AppState] Full cleanup done")
    }
}
