import Foundation
import MultipeerConnectivity

// MARK: - Message Envelope

struct MultipeerMessage: Codable {
    enum MessageType: String, Codable {
        case text
        case niDiscoveryToken
    }
    let type: MessageType
    let payload: Data
}

// MARK: - MultipeerManager

@Observable
final class MultipeerManager: NSObject {
    private let serviceType = "fit-challenge"

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // Observed by SwiftUI
    private(set) var foundPeers: [PeerInfo] = []
    private(set) var connectedPeer: MCPeerID?
    private(set) var pendingInvitingPeer: MCPeerID?

    // Not observed — internal only
    @ObservationIgnored private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    // Callbacks (wired by AppState)
    @ObservationIgnored var onPeerConnected: ((MCPeerID) -> Void)?
    @ObservationIgnored var onPeerDisconnected: (() -> Void)?
    @ObservationIgnored var onDataReceived: ((MultipeerMessage.MessageType, Data, MCPeerID) -> Void)?

    // MARK: - Init (no auto-start)

    init(customDisplayName: String) {
        self.peerID = MCPeerID(displayName: customDisplayName)
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)

        super.init()

        self.session.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self
    }

    // MARK: - Manual Discovery Controls

    func startAdvertising() {
        advertiser.startAdvertisingPeer()
        print("[MP] Started advertising")
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
        print("[MP] Started browsing")
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        DispatchQueue.main.async {
            self.foundPeers.removeAll()
        }
        print("[MP] Stopped discovery")
    }

    // MARK: - Manual Invite

    func invite(_ peerID: MCPeerID) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        print("[MP] Sending invite to: \(peerID.displayName)")
    }

    // MARK: - Invitation Response

    func acceptInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(true, session)
        pendingInvitationHandler = nil
        DispatchQueue.main.async { self.pendingInvitingPeer = nil }
        print("[MP] Invitation accepted")
    }

    func declineInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(false, nil)
        pendingInvitationHandler = nil
        DispatchQueue.main.async { self.pendingInvitingPeer = nil }
        print("[MP] Invitation declined")
    }

    // MARK: - Data Sending

    func sendData(_ data: Data) {
        guard !session.connectedPeers.isEmpty else {
            print("[MP] Cannot send: no connected peers")
            return
        }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("[MP] Sent \(data.count) bytes")
        } catch {
            print("[MP] Send error: \(error.localizedDescription)")
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        session.disconnect()
        DispatchQueue.main.async {
            self.connectedPeer = nil
            self.foundPeers.removeAll()
        }
        print("[MP] Disconnected")
    }
}

// MARK: - Browser Delegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peerInfo = PeerInfo(id: peerID)
        DispatchQueue.main.async {
            if !self.foundPeers.contains(peerInfo) {
                self.foundPeers.append(peerInfo)
                print("[MP] Found peer: \(peerID.displayName)")
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.foundPeers.removeAll { $0.id == peerID }
            print("[MP] Lost peer: \(peerID.displayName)")
        }
    }
}

// MARK: - Advertiser Delegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        print("[MP] Received invitation from: \(peerID.displayName)")
        // Store handler on whatever thread this arrives (safe — not an @Observable property)
        self.pendingInvitationHandler = invitationHandler
        // pendingInvitingPeer is @Observable — must update on main thread
        DispatchQueue.main.async {
            self.pendingInvitingPeer = peerID
        }
    }
}

// MARK: - Session Delegate

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // All state mutations on main thread (class is @Observable)
        switch state {
        case .notConnected:
            print("[MP] Disconnected from: \(peerID.displayName)")
            DispatchQueue.main.async {
                let wasConnected = self.connectedPeer == peerID
                if wasConnected { self.connectedPeer = nil }
                self.foundPeers.removeAll { $0.id == peerID }
                if wasConnected { self.onPeerDisconnected?() }
            }

        case .connecting:
            print("[MP] Connecting to: \(peerID.displayName)")

        case .connected:
            print("[MP] Connected to: \(peerID.displayName)")
            DispatchQueue.main.async {
                self.connectedPeer = peerID
                self.onPeerConnected?(peerID)
            }

        @unknown default:
            print("[MP] Unknown state for: \(peerID.displayName)")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Runs on background thread — decode here, then dispatch update to main
        if let message = try? JSONDecoder().decode(MultipeerMessage.self, from: data) {
            switch message.type {
            case .text:
                if let text = String(data: message.payload, encoding: .utf8) {
                    print("[MP] Text from \(peerID.displayName): \(text)")
                }
            case .niDiscoveryToken:
                print("[MP] Received NI token from \(peerID.displayName)")
                // onDataReceived handler (in AppState) will dispatch to main as needed
                onDataReceived?(.niDiscoveryToken, message.payload, peerID)
            }
        } else if let text = String(data: data, encoding: .utf8) {
            print("[MP] Legacy text from \(peerID.displayName): \(text)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
