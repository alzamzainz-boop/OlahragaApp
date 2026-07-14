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

    var hasCompletedOnboarding: Bool {
        !userName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Forwarded untuk SwiftUI observation reliability
    var pendingInvitingPeer: MCPeerID? {
        multipeerManager?.pendingInvitingPeer
    }

    func setupMultipeerManager() {
        guard !userName.isEmpty else { return }

        let manager = MultipeerManager(customDisplayName: userName)
        self.multipeerManager = manager

        manager.onDataReceived = { [weak self] type, payload, _ in
            if type == .niDiscoveryToken {
                self?.niManager.handleReceivedToken(payload)
            }
        }

        niManager.onSendTokenData = { [weak self] data in
            guard let self else { return }
            let envelope = MultipeerMessage(type: .niDiscoveryToken, payload: data)
            if let encoded = try? JSONEncoder().encode(envelope) {
                self.multipeerManager?.sendData(encoded)
            }
        }

        manager.onPeerConnected = { [weak self] _ in
            guard let self else { return }
            self.sendLocalNIToken()
            // Sudah di main thread (dispatched di MultipeerManager)
            self.navigationPath.append(.radar)
        }

        niManager.onNeedsTokenResend = { [weak self] in
            self?.sendLocalNIToken()
        }

        niManager.onProximityUpdate = { [weak self] distance in
            guard let self, distance < 2.0, self.currentRoom == nil else { return }
            let partnerName = self.multipeerManager?.connectedPeer?.displayName ?? "Partner"
            self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
            self.navigationPath.append(.room)
        }

        manager.onPeerDisconnected = { [weak self] in
            guard let self else { return }
            // Hanya clear state, JANGAN panggil reset() di sini
            // Biarkan fullCleanup() orchestrate cleanup terpusat
            self.currentRoom = nil
            self.navigationPath.removeAll()
        }
    }

    private func sendLocalNIToken() {
        guard let tokenData = niManager.localTokenData() else { return }
        let envelope = MultipeerMessage(type: .niDiscoveryToken, payload: tokenData)
        if let encoded = try? JSONEncoder().encode(envelope) {
            multipeerManager?.sendData(encoded)
            print("[AppState] Sent local NI token")
        }
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
