import Foundation
import SwiftUI

import MultipeerConnectivity

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

    func setupMultipeerManager() {
        guard !userName.isEmpty else { return }

        let manager = MultipeerManager(customDisplayName: userName)
        self.multipeerManager = manager

        // Wire: received NI token → pass to NI manager (arrives on background thread, NI handles dispatch internally)
        manager.onDataReceived = { [weak self] type, payload, _ in
            if type == .niDiscoveryToken {
                self?.niManager.handleReceivedToken(payload)
            }
        }

        // Wire: NI manager wants to send token → send via Multipeer
        niManager.onSendTokenData = { [weak self] data in
            guard let self else { return }
            let envelope = MultipeerMessage(type: .niDiscoveryToken, payload: data)
            if let encoded = try? JSONEncoder().encode(envelope) {
                self.multipeerManager?.sendData(encoded)
            }
        }

        // Wire: peer connected → send NI token immediately + navigate to radar
        manager.onPeerConnected = { [weak self] _ in
            guard let self else { return }
            self.sendLocalNIToken()
            // navigationPath is @Observable — already on main thread (dispatched by MultipeerManager)
            self.navigationPath.append(.radar)
        }

        // Wire: after reset(), NI needs to re-send token for session restart
        niManager.onNeedsTokenResend = { [weak self] in
            self?.sendLocalNIToken()
        }

        // Wire: proximity check for room formation
        niManager.onProximityUpdate = { [weak self] distance in
            guard let self, distance < 2.0, self.currentRoom == nil else { return }
            let partnerName = self.multipeerManager?.connectedPeer?.displayName ?? "Partner"
            // Already on main thread (NI manager dispatches to main before calling this)
            self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
            self.navigationPath.append(.room)
        }

        // Wire: peer disconnected → clean up NI + navigation
        manager.onPeerDisconnected = { [weak self] in
            guard let self else { return }
            // Already on main thread (dispatched by MultipeerManager)
            self.niManager.reset()
            self.currentRoom = nil
            self.navigationPath.removeAll()
        }
    }

    // MARK: - Helpers

    private func sendLocalNIToken() {
        guard let tokenData = niManager.localTokenData() else {
            print("[AppState] Could not get local NI token")
            return
        }
        let envelope = MultipeerMessage(type: .niDiscoveryToken, payload: tokenData)
        if let encoded = try? JSONEncoder().encode(envelope) {
            multipeerManager?.sendData(encoded)
            print("[AppState] Sent local NI token to peer")
        }
    }
}
