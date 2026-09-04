import AppUIKit
import Core
import SwiftUI

/// The Settings form (Source Spec §4.4 / §11). Deliberately thin: it renders
/// `viewModel.viewState` and funnels every gesture through
/// `viewModel.dispatch(_:)` — all behaviour and every test assertion live on
/// `SettingsViewModel`.
public struct SettingsView: View {
    @ObservedObject private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle(viewModel.tr("settings.title", default: "Cài đặt"))
            .onAppear { viewModel.dispatch(.onAppear) }
            .settingsLoadingDialog(
                isPresented: viewModel.uiState.isLoadingLanguage,
                message: viewModel.tr("settings.language.updating", default: "Đang cập nhật ngôn ngữ...")
            )
            .sheet(isPresented: Binding(
                get: { viewModel.uiState.isLanguagePickerPresented },
                set: { viewModel.dispatch(.showLanguagePicker($0)) }
            )) {
                LanguagePickerBottomSheet(
                    title: viewModel.tr("settings.preferences.language", default: "Ngôn ngữ"),
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
                    SettingsSectionCard(title: viewModel.tr("settings.account.title", default: "Tài khoản")) {
                        SettingsItemRow(
                            icon: "person.fill",
                            iconColor: .white,
                            iconBackground: .blue,
                            title: viewModel.tr("settings.account.profile", default: "Thông tin cá nhân"),
                            accessory: .chevron,
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "lock.fill",
                            iconColor: .white,
                            iconBackground: .blue,
                            title: viewModel.tr("settings.account.changePassword", default: "Đổi mật khẩu"),
                            accessory: .chevron,
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "shield.lefthalf.filled",
                            iconColor: .white,
                            iconBackground: .green,
                            title: viewModel.tr("settings.account.twoFactorAuth", default: "Xác thực 2 yếu tố"),
                            accessory: .navigation(tag: viewModel.tr(
                                "settings.account.twoFactorAuthOn",
                                default: "Bật"
                            )),
                            action: {}
                        )
                    }

                    // SECTION 2: TÙY CHỌN (PREFERENCES)
                    SettingsSectionCard(title: viewModel.tr("settings.preferences.title", default: "Tùy chọn")) {
                        SettingsItemRow(
                            icon: "dollarsign.circle.fill",
                            iconColor: .white,
                            iconBackground: .purple,
                            title: viewModel.tr("settings.preferences.currency", default: "Tiền tệ"),
                            accessory: .navigation(value: viewModel.tr(
                                "settings.preferences.currencyUsd",
                                default: "USD ($)"
                            )),
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "globe",
                            iconColor: .white,
                            iconBackground: .cyan,
                            title: viewModel.tr("settings.preferences.language", default: "Ngôn ngữ"),
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
                            title: viewModel.tr("settings.preferences.darkMode", default: "Chế độ tối"),
                            accessory: .toggle(Binding(
                                get: { settings.isDarkMode },
                                set: { _ in viewModel.dispatch(.toggleDarkMode) }
                            ))
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "bell.fill",
                            iconColor: .white,
                            iconBackground: .blue,
                            title: viewModel.tr("settings.preferences.notifications", default: "Thông báo đẩy"),
                            accessory: .toggle(Binding(
                                get: { settings.notificationsEnabled },
                                set: { _ in viewModel.dispatch(.toggleNotifications) }
                            ))
                        )
                    }

                    // SECTION 3: NHÀ PHÁT TRIỂN (DEVELOPER)
                    SettingsSectionCard(title: viewModel.tr("settings.developer.title", default: "Nhà phát triển")) {
                        SettingsItemRow(
                            icon: "hammer.fill",
                            iconColor: .white,
                            iconBackground: .teal,
                            title: viewModel.tr("settings.developer.debugMode", default: "Chế độ gỡ lỗi"),
                            accessory: .toggle(Binding(
                                get: { viewModel.uiState.isDeveloperModeEnabled },
                                set: { viewModel.dispatch(.toggleDeveloperMode($0)) }
                            ))
                        )
                    }

                    // SECTION 4: THÔNG TIN ỨNG DỤNG (APP INFORMATION)
                    SettingsSectionCard(title: viewModel.tr("settings.appInfo.title", default: "Thông tin ứng dụng")) {
                        SettingsItemRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .white,
                            iconBackground: .green,
                            title: viewModel.tr("settings.appInfo.contactSupport", default: "Liên hệ hỗ trợ"),
                            accessory: .chevron,
                            action: {}
                        )
                        Divider().padding(.leading, 48)
                        SettingsItemRow(
                            icon: "info.circle.fill",
                            iconColor: .white,
                            iconBackground: .gray,
                            title: viewModel.tr("settings.appInfo.aboutApp", default: "Về ứng dụng"),
                            accessory: .value(viewModel.uiState.appVersion)
                        )
                    }

                    // LOGOUT BUTTON
                    logoutButton

                    // Saving / Loading indicator
                    if viewModel.uiState.isSaving || viewModel.uiState.isLoadingLanguage {
                        HStack(spacing: AppSpacing.sm) {
                            ProgressView()
                            Text(viewModel.uiState.isLoadingLanguage ? viewModel.tr(
                                "settings.loadingLanguage",
                                default: "Đang tải ngôn ngữ…"
                            ) : viewModel.tr("settings.saving", default: "Đang lưu…"))
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
                Text(viewModel.tr("settings.logout", default: "Đăng xuất"))
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
