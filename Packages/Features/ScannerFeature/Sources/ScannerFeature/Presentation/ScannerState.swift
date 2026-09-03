/// The Scanner screen's single observable state (Source Spec §5.4).
public struct ScannerState: Equatable {
    /// The scanner data currently shown. Starts as `.stub` and, in the
    /// template, never changes.
    public var entity: ScannerEntity

    public init(entity: ScannerEntity = .stub) {
        self.entity = entity
    }
}
