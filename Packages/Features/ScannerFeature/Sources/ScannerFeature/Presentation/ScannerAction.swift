/// User intents the Scanner screen can receive (Source Spec §5.4). The stub only
/// needs one.
public enum ScannerAction: Equatable {
    /// The screen appeared — (re)load the stub scanner data.
    case onAppear
}
