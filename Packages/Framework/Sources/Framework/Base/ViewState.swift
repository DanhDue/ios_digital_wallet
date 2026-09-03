/// The three render states a screen can be in, parameterised by its content
/// model (Source Spec §5.3). Not `Equatable` — the `error` case carries an
/// arbitrary `Error`; tests compare via a discriminator helper.
public enum ViewState<STATE> {
    case loading
    case error(Error)
    case content(STATE)
}
