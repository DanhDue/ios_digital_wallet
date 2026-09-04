/// One-shot effects the Settings screen emits on its `eventSubject`
/// (Source Spec §5.4).
public enum SettingsEvent: Equatable {
    /// A persist attempt failed; the optimistic change has already been rolled
    /// back. Carries the user-facing failure message.
    case saveFailed(String)
}
