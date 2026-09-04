import AppUIKit
import SwiftUI

/// Modal bottom sheet for choosing application language with instant checkmark feedback.
private struct BottomSheetHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct ListContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

/// Modal bottom sheet for choosing application language with instant checkmark feedback.
/// Supports wrap-content sizing that adapts automatically to the number of language options.
public struct LanguagePickerBottomSheet: View {
    private let title: String
    private let languages: [AvailableLanguage]
    private let currentLanguageCode: String
    private let onSelect: (String) -> Void

    @State private var measuredListHeight: CGFloat = 0
    @State private var measuredSheetHeight: CGFloat = 0

    public init(
        title: String = "Ngôn ngữ",
        languages: [AvailableLanguage],
        currentLanguageCode: String,
        onSelect: @escaping (String) -> Void
    ) {
        self.title = title
        self.languages = languages
        self.currentLanguageCode = currentLanguageCode
        self.onSelect = onSelect

        let initialList = min(CGFloat(max(1, languages.count)) * 52.0, 360.0)
        _measuredListHeight = State(initialValue: initialList)
        _measuredSheetHeight = State(initialValue: initialList + 100.0)
    }

    private var effectiveListHeight: CGFloat {
        min(measuredListHeight > 0 ? measuredListHeight : 160.0, 360.0)
    }

    private var effectiveSheetHeight: CGFloat {
        if measuredSheetHeight > 0 {
            return min(measuredSheetHeight, 520.0)
        }
        return effectiveListHeight + 100.0
    }

    private var detents: Set<PresentationDetent> {
        if languages.count > 5 {
            return [.height(effectiveSheetHeight), .large]
        }
        return [.height(effectiveSheetHeight)]
    }

    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Sheet Header
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
                .padding(.top, AppSpacing.md)

            Divider()

            // Languages list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(languages) { lang in
                        languageRow(lang)
                        if lang.id != languages.last?.id {
                            Divider()
                                .padding(.leading, AppSpacing.md)
                        }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, AppSpacing.md)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ListContentHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                )
            }
            .frame(height: effectiveListHeight)
            .scrollDisabled(measuredListHeight <= 360.0)
            .padding(.bottom, AppSpacing.md)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: BottomSheetHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(ListContentHeightPreferenceKey.self) { newHeight in
            if newHeight > 0 {
                measuredListHeight = newHeight
            }
        }
        .onPreferenceChange(BottomSheetHeightPreferenceKey.self) { newHeight in
            if newHeight > 0 {
                measuredSheetHeight = newHeight
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .background(Color.appBackground)
    }

    private func languageRow(_ lang: AvailableLanguage) -> some View {
        let isSelected = (lang.languageCode == currentLanguageCode)
        return Button {
            onSelect(lang.languageCode)
        } label: {
            HStack {
                Text(lang.languageName)
                    .font(.body)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.appPrimary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
