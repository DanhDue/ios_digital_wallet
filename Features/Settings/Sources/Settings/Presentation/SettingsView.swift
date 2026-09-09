import AppUIKit
import Core
import Platform
import SwiftUI

/// The Settings form (Source Spec §4.4 / §11). Deliberately thin: it renders
/// `viewModel.viewState` and funnels every gesture through
/// `viewModel.dispatch(_:)` — all behaviour and every test assertion live on
/// `SettingsViewModel`.
public struct SettingsView: View {
    @ObservedObject private var viewModel: SettingsViewModel
    @Environment(\.t) private var t: Translations
    @Environment(\.themeManager) private var themeManager: AppThemeManager

    public init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle(t.settings.title)
            .onAppear { viewModel.dispatch(.onAppear) }
            .settingsLoadingDialog(
                isPresented: viewModel.uiState.isLoadingLanguage,
                message: t.settings.language.updating
            )
            .sheet(isPresented: Binding(
                get: { viewModel.uiState.isLanguagePickerPresented },
                set: { viewModel.dispatch(.showLanguagePicker($0)) }
            )) {
                LanguagePickerBottomSheet(
                    title: t.settings.preferences.language,
                    languages: viewModel.uiState.settings.availableLanguages,
                    currentLanguageCode: viewModel.uiState.settings.language,
                    onSelect: { code in
                        viewModel.dispatch(.selectLanguage(code))
                    }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading, .content:
            cardList
        case let .error(error):
            AppErrorView(message: Self.message(for: error)) {
                viewModel.dispatch(.onAppear)
            }
        }
    }

    private var cardList: some View {
        let settings = viewModel.uiState.settings
        let currentLangName = settings.availableLanguages
            .first { $0.languageCode == settings.language }?.languageName ?? settings.language.uppercased()

        return ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // SECTION 1: TÀI KHOẢN (ACCOUNT)
                    SettingsSectionCard(title: t.settings.account.title) {
                        SettingsItemRow(
                            icon: "person.fill",
                            iconColor: .white,
                            iconBackground: .blue,
                            title: t.settings.account.profile,
                            accessory: .chevron,
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "lock.fill",
                            iconColor: .white,
                            iconBackground: .blue,
                            title: t.settings.account.changePassword,
                            accessory: .chevron,
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "shield.lefthalf.filled",
                            iconColor: .white,
                            iconBackground: .green,
                            title: t.settings.account.twoFactorAuth,
                            accessory: .navigation(tag: t.settings.account.twoFactorAuthOn),
                            action: {}
                        )
                    }

                    // SECTION 2: TÙY CHỌN (PREFERENCES)
                    SettingsSectionCard(title: t.settings.preferences.title) {
                        SettingsItemRow(
                            icon: "dollarsign.circle.fill",
                            iconColor: .white,
                            iconBackground: .purple,
                            title: t.settings.preferences.currency,
                            accessory: .navigation(value: t.settings.preferences.currencyUsd),
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "globe",
                            iconColor: .white,
                            iconBackground: .cyan,
                            title: t.settings.preferences.language,
                            accessory: .navigation(value: currentLangName),
                            action: {
                                viewModel.dispatch(.showLanguagePicker(true))
                            }
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "moon.fill",
                            iconColor: .white,
                            iconBackground: .orange,
                            title: t.settings.preferences.darkMode,
                            accessory: .toggle(Binding(
                                get: { settings.isDarkMode },
                                set: { isDark in
                                    themeManager.setMode(isDark ? .dark : .light)
                                    viewModel.dispatch(.toggleDarkMode)
                                }
                            ))
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "bell.fill",
                            iconColor: .white,
                            iconBackground: .blue,
                            title: t.settings.preferences.notifications,
                            accessory: .toggle(Binding(
                                get: { settings.notificationsEnabled },
                                set: { _ in viewModel.dispatch(.toggleNotifications) }
                            ))
                        )
                    }

                    // SECTION 3: NHÀ PHÁT TRIỂN (DEVELOPER)
                    SettingsSectionCard(title: t.settings.developer.title) {
                        SettingsItemRow(
                            icon: "hammer.fill",
                            iconColor: .white,
                            iconBackground: .teal,
                            title: t.settings.developer.debugMode,
                            accessory: .toggle(Binding(
                                get: { viewModel.uiState.isDeveloperModeEnabled },
                                set: { viewModel.dispatch(.toggleDeveloperMode($0)) }
                            ))
                        )
                    }

                    // SECTION 4: THÔNG TIN ỨNG DỤNG (APP INFORMATION)
                    SettingsSectionCard(title: t.settings.appInfo.title) {
                        SettingsItemRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .white,
                            iconBackground: .green,
                            title: t.settings.appInfo.contactSupport,
                            accessory: .chevron,
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "info.circle.fill",
                            iconColor: .white,
                            iconBackground: .gray,
                            title: t.settings.appInfo.aboutApp,
                            accessory: .value(viewModel.uiState.appVersion)
                        )
                    }

                    // LOGOUT BUTTON
                    logoutButton

                    // Saving / Loading indicator
                    if viewModel.uiState.isSaving || viewModel.uiState.isLoadingLanguage {
                        HStack(spacing: AppSpacing.sm) {
                            ProgressView()
                            Text(viewModel.uiState.isLoadingLanguage ? t.settings.loadingLanguage : t.settings.saving)
                                .font(.footnote)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.top, AppSpacing.xs)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
            }
        }
    }

    private var logoutButton: some View {
        Button {
            // Standalone Logout action
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text(t.settings.logout)
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private static func message(for error: Error) -> String {
        (error as? AppError)?.message ?? "Something went wrong."
    }
}
