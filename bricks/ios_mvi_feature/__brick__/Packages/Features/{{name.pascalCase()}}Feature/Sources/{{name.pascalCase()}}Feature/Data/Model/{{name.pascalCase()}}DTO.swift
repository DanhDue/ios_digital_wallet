/// The on-disk / on-the-wire shape of the `{{name.pascalCase()}}` value.
/// Deliberately separate from `{{name.pascalCase()}}Entity` so a storage- or
/// API-format change never ripples into the Domain (Source Spec §4.4).
///
/// `internal` — the whole `Data` layer is reached only through
/// `{{name.pascalCase()}}Repository` (ArchTests K4).
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Data/Model/SettingsDTO.swift
struct {{name.pascalCase()}}DTO: Codable, Equatable {
    let title: String
    let count: Int
}
