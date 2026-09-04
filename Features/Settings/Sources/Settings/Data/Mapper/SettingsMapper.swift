/// Total, allocation-free translation between the storage/network DTOs and the Domain
/// entities. No validation — a decoded DTO is trusted; policy lives in the
/// use cases (Source Spec §4.4). `internal` (ArchTests K4).
enum SettingsMapper {
    static func toEntity(_ dto: SettingsDTO) -> SettingsEntity {
        SettingsEntity(
            isDarkMode: dto.isDarkMode,
            language: dto.language,
            notificationsEnabled: dto.notificationsEnabled
        )
    }

    static func toDTO(_ entity: SettingsEntity) -> SettingsDTO {
        SettingsDTO(
            isDarkMode: entity.isDarkMode,
            language: entity.language,
            notificationsEnabled: entity.notificationsEnabled
        )
    }

    static func toLanguageEntity(_ dto: AvailableLanguageDTO) -> AvailableLanguage {
        AvailableLanguage(
            languageCode: dto.languageCode,
            languageName: dto.languageName,
            isDefault: dto.isDefault ?? false,
            isActive: dto.isActive ?? true
        )
    }

    static func toLanguageDTO(_ entity: AvailableLanguage) -> AvailableLanguageDTO {
        AvailableLanguageDTO(
            languageCode: entity.languageCode,
            languageName: entity.languageName,
            isDefault: entity.isDefault,
            isActive: entity.isActive
        )
    }

    static func toOverrideEntity(_ dto: TranslationOverrideDTO) -> TranslationOverride {
        TranslationOverride(
            version: dto.version,
            translations: dto.translations,
            checksum: dto.checksum
        )
    }
}
