import Plugin
import SwiftUI

/// Root content view for the Sample runner app.
public struct ContentView: View {
    @State private var isSyncing = false
    @State private var syncStatus: String?

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Direct mounting of the plugin SwiftUI screen
                MyPluginView()

                Divider()

                VStack(spacing: 8) {
                    Button(action: triggerSync) {
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Trigger Background Sync UseCase")
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(isSyncing)

                    if let syncStatus {
                        Text(syncStatus)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Plugin DevBed Runner")
        }
    }

    private func triggerSync() {
        isSyncing = true
        syncStatus = "Syncing..."
        Task {
            do {
                let useCase = PluginContainer.shared.syncDataUseCase()
                try await useCase.execute()
                await MainActor.run {
                    isSyncing = false
                    syncStatus = "Sync succeeded at \(Date().formatted(date: .omitted, time: .standard))"
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncStatus = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
