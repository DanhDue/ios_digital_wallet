/// Optional envelope mirroring a common `{ data, message, status }` API
/// response shape. `send()` does NOT use this automatically — a feature that
/// wants it decodes `send() as BaseResponseObject<Foo>` and reads `.data`. The
/// template imposes no backend response shape by default.
public struct BaseResponseObject<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: T?
    public let message: String?
    public let status: Int?

    public init(data: T? = nil, message: String? = nil, status: Int? = nil) {
        self.data = data
        self.message = message
        self.status = status
    }
}
