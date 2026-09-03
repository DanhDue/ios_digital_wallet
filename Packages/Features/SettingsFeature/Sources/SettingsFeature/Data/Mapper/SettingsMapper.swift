/// Total, allocation-free translation between the storage DTO and the Domain
/// entity. No validation — a decoded DTO is trusted; policy lives in the
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
}
