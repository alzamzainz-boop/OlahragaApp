import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var nameInput: String = ""
    @State private var navigateToDiscovery = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "figure.run")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)

                Text("Welcome to Flint")
                    .font(.largeTitle.bold())

                Text("Enter your name so others can find you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Your name", text: $nameInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("Continue") {
                    let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    appState.userName = trimmed
                    appState.setupMultipeerManager()
                    navigateToDiscovery = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $navigateToDiscovery) {
                DiscoveryView()
            }
        }
    }
}
