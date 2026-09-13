---
trigger: always_on
---

# Localization & Translations — Agent Rules (DOs & DON'Ts)

Mandatory rules for AI agents working on the localization system of the **iOS Super App
Template**. Full background: [`docs/LOCALIZATION.md`](../../docs/LOCALIZATION.md).

---

## 1. Core Principles

### 1. Decentralized catalogs

Strings live in the `Localizable.xcstrings` of the module that owns them:

- Feature: `Features/<Feature>/Sources/<Feature>/Resources/Localizable.xcstrings`
- Shell: `Packages/Shell/Sources/Shell/Resources/Localizable.xcstrings`

❌ **Never** add a string directly to `App/Resources/Localizable.xcstrings` or
`Packages/Platform/Resources/Localizable.xcstrings`. Those two are **auto-generated
destinations** — anything written there is overwritten on the next sync.

### 2. Key naming convention

- Every segment of a key **must** be `camelCase` (`^[a-z][a-zA-Z0-9]*$`).
- ❌ No `snake_case` (`settings.user_profile`), `kebab-case` (`settings.user-profile`), or
  `PascalCase` (`Settings.Account.Title`).
- Minimum two segments: `<feature>.<key>`. ❌ No bare, unprefixed keys such as `"title"` or
  `"logout"`.

### 3. Hierarchical scoping

- **Feature level (2 segments)** — `<feature>.<key>`, e.g. `settings.title`, `settings.logout`,
  `scanner.title`. Use for a screen's root title, buttons, and messages shared across the feature.
- **Subfeature level (3 segments)** — `<feature>.<subfeature>.<key>`, e.g.
  `settings.account.profile`, `settings.preferences.darkMode`. Use for sub-screens
  (`Presentation/<Subfeature>/`), section cards, and bottom sheets.
- The `<feature>` prefix must match the owning module: anything in `Features/Settings` starts
  with `settings.`.

### 4. No structural collision

A key must never be a prefix of another key (leaf vs. branch collision).

- ❌ **Wrong**: `"settings.account"` as a leaf string while `"settings.account.profile"` exists.
- ✅ **Right**: `"settings.account.title"` alongside `"settings.account.profile"`.

### 5. Use in SwiftUI views

- Declare `@Environment(\.t) private var t: Translations`.
- Use the type-safe dot notation: `t.<feature>.<key>` or `t.<feature>.<subfeature>.<key>`.
- ❌ Avoid hardcoded literals — `Text("...")` or `t("literal.key")` — when a typed accessor
  already exists.

### 6. Static vs. OTA languages

- The binary bundles **only `en` (English)** and **`vi` (Vietnamese)**.
- ❌ Do **not** add `ja`, `ko`, or any other language to a local `.xcstrings`. They are loaded
  entirely over the air.

### 7. Re-sync is mandatory after any edit

After adding, changing, or removing **any** key in a `.xcstrings`, run:

```bash
python3 scripts/merge_localizations.py
```

(or build in Xcode, which triggers it). It:

- runs the `validate_catalogs` checks,
- syncs the master catalogs,
- regenerates `Translations.generated.swift`,
- exports the backend JSON to `App/Resources/backend_translations/`.

---

## 2. Pre-completion checklist

- [ ] Does the `.xcstrings` still carry `"version": "1.0"` at its root?
- [ ] Is every new key `camelCase` (`^[a-z][a-zA-Z0-9]*$`)?
- [ ] Does each key's prefix match the feature that owns it?
- [ ] Is there no leaf/branch collision (`<name>` vs `<name>.<child>`)?
- [ ] Did `python3 scripts/merge_localizations.py` report
      `🛡️ All module catalogs passed DOs & DON'Ts validation rules`?
- [ ] Do `swift test --package-path ArchTests` and `mise exec -- swiftlint` both pass?
