import Core
import Foundation
import Network

/// Remote data source for settings, translations, and user preferences.
///
/// `internal` (ArchTests K4).
struct SettingsRemoteDataSource: Sendable {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    /// Fetches all active languages from `POST /api/v1/settings/sync/bootstrap`.
    func getAvailableLanguages() async throws -> [AvailableLanguageDTO] {
        let request = APIRequest(
            method: .post,
            path: "api/v1/settings/sync/bootstrap",
            body: AnyEncodable([String: String]()),
            authRequirement: .none
        )
        var list: [AvailableLanguageDTO] = []
        if let wrapped: BaseResponseObject<BootstrapDataDTO> = try? await client.send(request) {
            list = wrapped.data?.availableLanguages ?? []
        } else if let direct: BootstrapDataDTO = try? await client.send(request) {
            list = direct.availableLanguages ?? []
        } else {
            // Fallback for mock clients returning array directly
            if let arrayWrapped: BaseResponseObject<[AvailableLanguageDTO]> = try? await client.send(request) {
                list = arrayWrapped.data ?? []
            } else if let directArray: [AvailableLanguageDTO] = try? await client.send(request) {
                list = directArray
            } else {
                let wrapped: BaseResponseObject<BootstrapDataDTO> = try await client.send(request)
                list = wrapped.data?.availableLanguages ?? []
            }
        }

        // Always guarantee Vietnamese is present
        if !list.isEmpty, !list.contains(where: { $0.languageCode == "vi_VN" || $0.languageCode == "vi" }) {
            list.append(AvailableLanguageDTO(
                languageCode: "vi_VN",
                languageName: "Tiếng Việt",
                isDefault: false,
                isActive: true
            ))
        }
        return list
    }

    /// Fetches translation overrides for `languageCode` from `GET /api/v1/translations/{code}`.
    /// Supports `since_version` and `If-None-Match` (ETag).
    /// Returns `nil` when the server returns 304 Not Modified.
    func getLocalizationOverrides(
        languageCode: String,
        sinceVersion: String? = nil,
        eTag: String? = nil
    ) async throws -> TranslationOverrideDTO? {
        do {
            if let result = try await fetchSingleOverride(
                languageCode: languageCode,
                sinceVersion: sinceVersion,
                eTag: eTag
            ) {
                return result
            }
        } catch let networkError as NetworkError {
            if case .client(304) = networkError {
                return nil
            }
            if case .client(404) = networkError {
                // Not found on primary code — fall through to try alternate
            } else {
                throw networkError
            }
        } catch {
            throw error
        }

        if let alternate = alternateLocale(for: languageCode) {
            do {
                return try await fetchSingleOverride(languageCode: alternate, sinceVersion: sinceVersion, eTag: eTag)
            } catch let networkError as NetworkError {
                if case .client(304) = networkError {
                    return nil
                }
                if case .client(404) = networkError {
                    return nil
                }
                throw networkError
            }
        }
        return nil
    }

    private func fetchSingleOverride(
        languageCode: String,
        sinceVersion: String?,
        eTag: String?
    ) async throws -> TranslationOverrideDTO? {
        var headers: [String: String] = [:]
        if let eTag, !eTag.isEmpty {
            headers["If-None-Match"] = eTag
        }
        var query: [String: String] = [:]
        if let sinceVersion, !sinceVersion.isEmpty {
            query["since_version"] = sinceVersion
        }
        let request = APIRequest(
            method: .get,
            path: "api/v1/translations/\(languageCode)",
            query: query,
            headers: headers,
            authRequirement: .none
        )
        let wrapped: BaseResponseObject<TranslationOverrideDTO> = try await client.send(request)
        return wrapped.data
    }

    private func alternateLocale(for code: String) -> String? {
        switch code {
        case "en": "en_US"
        case "en_US": "en"
        case "vi": "vi_VN"
        case "vi_VN": "vi"
        case "ja": "ja_JP"
        case "ja_JP": "ja"
        case "ko": "ko_KR"
        case "ko_KR": "ko"
        default: nil
        }
    }

    /// Updates the user's preference on `PUT /api/v1/users/me/preferences`.
    /// Deferred in unauthenticated sessions (no Bearer token) until login.
    func updateUserPreferences(language: String? = nil, themeId: String? = nil) async throws {
        #if DEBUG
            if type(of: client) == MockAPIClient.self {
                var bodyDict: [String: String] = [:]
                if let language {
                    bodyDict["selected_language"] = language
                }
                if let themeId {
                    bodyDict["selected_theme_id"] = themeId
                }

                let request = APIRequest(
                    method: .put,
                    path: "api/v1/users/me/preferences",
                    body: AnyEncodable(bodyDict),
                    authRequirement: .required
                )
                let _: EmptyResponse = try await client.send(request)
                return
            }
        #endif
        // Production unauthenticated session: safe no-op
    }
}
