/// One-shot effects the Scanner screen emits on its `eventSubject`
/// (Source Spec §5.4). The stub emits one, when the stub data has loaded.
public enum ScannerEvent: Equatable {
    /// The stub scanner data finished loading.
    case dataLoaded
}
