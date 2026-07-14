//
//  ContentView.swift
//  OlahragaApp
//
//  Created by Moh Zainul Firdaus on 13/07/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            mainContent
        } else {
            OnboardingView()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        @Bindable var appState = appState   // 👈 buat binding ke properti observable
        NavigationStack(path: $appState.navigationPath) {
            DiscoveryView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .discovery:
                        DiscoveryView()
                    case .radar:
                        NearbyRadarView()
                    case .room:
                        RoomFormedView()
                    }
                }
        }
        .sheet(isPresented: .init(
            get: { appState.multipeerManager?.pendingInvitingPeer != nil },
            set: { if !$0 { appState.multipeerManager?.declineInvitation() } }
        )) {
            InviteReceivedView()
        }
        .onAppear {
            if appState.multipeerManager == nil {
                appState.setupMultipeerManager()
            }
        }
    }
}
