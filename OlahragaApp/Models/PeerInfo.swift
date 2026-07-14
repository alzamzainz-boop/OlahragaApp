import Foundation
import MultipeerConnectivity

struct PeerInfo: Identifiable, Equatable {
    let id: MCPeerID
    var displayName: String { id.displayName }

    static func == (lhs: PeerInfo, rhs: PeerInfo) -> Bool {
        lhs.id == rhs.id
    }
}
