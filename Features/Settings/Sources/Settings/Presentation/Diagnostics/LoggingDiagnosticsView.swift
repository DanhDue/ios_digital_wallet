#if DEBUG
    import AppUIKit
    import SwiftUI

    /// Developer-facing diagnostics screen displaying runtime module mutes,
    /// appender kill-switches, and quick access to the Pulse console.
    public struct LoggingDiagnosticsView: View {
        @ObservedObject private var viewModel: LoggingDiagnosticsViewModel

        public init(viewModel: LoggingDiagnosticsViewModel) {
            self.viewModel = viewModel
        }

        public var body: some View {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Console launcher card
                    SettingsSectionCard(title: "Telemetry Console") {
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Pulse Inspector")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.appTextPrimary)
                                Text("Inspect live logs, network traces, and leaks")
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            Button("Open") {
                                viewModel.openConsole()
                                NotificationCenter.default.post(
                                    name: Notification.Name("UIDeviceDidShakeNotification"),
                                    object: nil
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, AppSpacing.sm)
                    }

                    // Appender kill-switches card
                    SettingsSectionCard(title: "Appenders (Kill-Switches)") {
                        ForEach(LoggingDiagnosticsViewModel.availableAppenders, id: \.self) { appender in
                            Toggle(isOn: Binding(
                                get: { viewModel.appenderToggles[appender] ?? true },
                                set: { viewModel.setAppenderEnabled(appender, enabled: $0) }
                            )) {
                                Text(appender.uppercased())
                                    .font(.body)
                                    .foregroundStyle(Color.appTextPrimary)
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                    }

                    // Module mutes card
                    SettingsSectionCard(title: "Modules (Mute Toggles)") {
                        ForEach(LoggingDiagnosticsViewModel.availableModules, id: \.self) { module in
                            Toggle(isOn: Binding(
                                get: { viewModel.moduleToggles[module] ?? true },
                                set: { viewModel.setModuleEnabled(module, enabled: $0) }
                            )) {
                                Text(module)
                                    .font(.body)
                                    .foregroundStyle(Color.appTextPrimary)
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Diagnostics")
        }
    }
#endif
