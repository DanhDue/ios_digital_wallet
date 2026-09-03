/// Total, allocation-free translation between the storage / wire DTO and the
/// Domain entity. No validation — a decoded DTO is trusted; policy lives in the
/// use cases (Source Spec §4.4). `internal` (ArchTests K4).
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Data/Mapper/SettingsMapper.swift
enum {{name.pascalCase()}}Mapper {
    static func toEntity(_ dto: {{name.pascalCase()}}DTO) -> {{name.pascalCase()}}Entity {
        {{name.pascalCase()}}Entity(title: dto.title, count: dto.count)
    }

    static func toDTO(_ entity: {{name.pascalCase()}}Entity) -> {{name.pascalCase()}}DTO {
        {{name.pascalCase()}}DTO(title: entity.title, count: entity.count)
    }
}
