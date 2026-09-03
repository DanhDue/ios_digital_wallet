import XCTest
@testable import SettingsFeature

final class SettingsMapperTests: XCTestCase {
    func testEntityToDTOToEntityIsIdentity() {
        let cases = [
            SettingsEntity(isDarkMode: false, language: "en", notificationsEnabled: true),
            SettingsEntity(isDarkMode: true, language: "vi", notificationsEnabled: false),
            SettingsEntity(isDarkMode: true, language: "", notificationsEnabled: true),
            SettingsEntity(isDarkMode: false, language: "zh-Hans-CN-x-very-long", notificationsEnabled: false),
        ]

        for entity in cases {
            let roundTripped = SettingsMapper.toEntity(SettingsMapper.toDTO(entity))
            XCTAssertEqual(roundTripped, entity)
        }
    }

    func testDTOToEntityCopiesEveryField() {
        let dto = SettingsDTO(isDarkMode: true, language: "ja", notificationsEnabled: false)

        let entity = SettingsMapper.toEntity(dto)

        XCTAssertEqual(entity.isDarkMode, true)
        XCTAssertEqual(entity.language, "ja")
        XCTAssertEqual(entity.notificationsEnabled, false)
    }

    func testEntityToDTOCopiesEveryField() {
        let entity = SettingsEntity(isDarkMode: false, language: "fr", notificationsEnabled: true)

        let dto = SettingsMapper.toDTO(entity)

        XCTAssertEqual(dto.isDarkMode, false)
        XCTAssertEqual(dto.language, "fr")
        XCTAssertEqual(dto.notificationsEnabled, true)
    }

    func testDTODecodesFromItsJSONRepresentation() throws {
        let json = Data(#"{"isDarkMode":true,"language":"de","notificationsEnabled":false}"#.utf8)

        let dto = try JSONDecoder().decode(SettingsDTO.self, from: json)

        XCTAssertEqual(
            SettingsMapper.toEntity(dto),
            SettingsEntity(isDarkMode: true, language: "de", notificationsEnabled: false)
        )
    }
}
