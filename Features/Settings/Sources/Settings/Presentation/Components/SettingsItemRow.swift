import AppUIKit
import SwiftUI

/// Trailing accessory type for a settings row.
public enum SettingsItemAccessory {
    case chevron
    case value(String)
    case navigation(value: String? = nil, tag: String? = nil)
    case toggle(Binding<Bool>)
}

/// A row inside a SettingsSectionCard matching the super app design.
public struct SettingsItemRow: View {
    private let icon: String
    private let iconColor: Color
    private let iconBackground: Color
    private let title: String
    private let accessory: SettingsItemAccessory
    private let action: (() -> Void)?

    public init(
        icon: String,
        iconColor: Color = .white,
        iconBackground: Color = .appPrimary,
        title: String,
        accessory: SettingsItemAccessory = .chevron,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackground = iconBackground
        self.title = title
        self.accessory = accessory
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Circular icon badge
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                // Title
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                // Accessory
                trailingAccessory
            }
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil && !isToggle)
    }

    private var isToggle: Bool {
        if case .toggle = accessory {
            return true
        }
        return false
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)

        case let .value(text):
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

        case let .navigation(value, tag):
            HStack(spacing: AppSpacing.xs) {
                if let tag {
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }

        case let .toggle(binding):
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(Color.appPrimary)
        }
    }
}
