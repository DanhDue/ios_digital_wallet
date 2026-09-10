/// One-shot effects the `Result` sub-screen emits on its `eventSubject`
/// (Source Spec §5.4). The screen has none to emit — it only displays the
/// code it was constructed with, synchronously, with no I/O to report on.
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsEvent.swift
public enum ResultEvent: Equatable {}
