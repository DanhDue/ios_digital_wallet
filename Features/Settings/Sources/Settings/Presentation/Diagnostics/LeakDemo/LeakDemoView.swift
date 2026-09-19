#if DEBUG
    import AppUIKit
    import SwiftUI

    /// Diagnostic screen allowing developers to simulate a retain cycle
    /// and observe `LeakSentinel` reporting in the Pulse console.
    public struct LeakDemoView: View {
        @ObservedObject private var viewModel: LeakDemoViewModel

        public init(viewModel: LeakDemoViewModel) {
            self.viewModel = viewModel
        }

        public var body: some View {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Status Card
                    SettingsSectionCard(title: "Current Status") {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Status: \(viewModel.uiState.statusMessage)")
                                .font(.body)
                                .foregroundStyle(Color.appTextPrimary)

                            HStack(spacing: AppSpacing.md) {
                                StatusBadge(
                                    label: "Leak Triggered",
                                    isActive: viewModel.uiState.isLeakingTriggered,
                                    activeColor: .orange
                                )
                                StatusBadge(
                                    label: "Clean Triggered",
                                    isActive: viewModel.uiState.isCleanTriggered,
                                    activeColor: .green
                                )
                            }
                            .padding(.top, AppSpacing.xs)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }

                    // Actions Card
                    SettingsSectionCard(title: "Simulate Scenarios") {
                        VStack(spacing: AppSpacing.md) {
                            Button {
                                viewModel.dispatch(.triggerLeak)
                            } label: {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.orange)
                                    Text("Trigger Leaking Flow")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.xs)
                            }
                            .buttonStyle(.plain)

                            Divider()

                            Button {
                                viewModel.dispatch(.triggerClean)
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                    Text("Trigger Clean Flow")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.xs)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }

                    // Verification Instructions Card
                    SettingsSectionCard(title: "How to Verify") {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("1. Tap 'Trigger Leaking Flow' above.")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                            Text("2. Navigate back to previous screen.")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                            Text("3. Wait 3 seconds for the Sentinel grace period.")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                            Text("4. Shake device to open the Pulse console.")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                            Text("5. Observe the .error log: 'Potential memory leak detected: LeakDemoViewModel'.")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Leak Sentinel Demo")
            .onAppear {
                viewModel.dispatch(.onAppear)
            }
            .onDisappear {
                viewModel.dispatch(.onDisappear)
            }
        }
    }

    private struct StatusBadge: View {
        let label: String
        let isActive: Bool
        let activeColor: Color

        var body: some View {
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(isActive ? activeColor : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isActive ? Color.appTextPrimary : Color.appTextSecondary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.appSurface)
            .cornerRadius(8)
        }
    }
#endif
