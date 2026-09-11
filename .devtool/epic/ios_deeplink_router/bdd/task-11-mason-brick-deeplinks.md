# Scenario Analysis — Task 11: Mason ios_mvi_feature Brick deepLinks Scaffold

Captured from the implementer's QA pass at implementation time (2026-09-11).
This task is a code-generator change, so the repo's Tier B standard applies
instead of RED-first TDD: the record below is boundary analysis over the
brick's only input (the feature name). The executable form is the seven-scenario
verification table, executed and pasted in the task report.
Task: [task_11_mason_brick_deeplinks](../../../features/task_11_mason_brick_deeplinks.md)

### SCENARIO ANALYSIS

Input under test: the Mason `name` variable (PascalCase feature name), fed
through `{{name.paramCase()}}` into the new `DeepLinkRoute("/...")` literal.
Verified empirically by generating with `--no-hooks -o <scratch-dir>` (no repo
side effects) for each partition and reading the existing `paramCase()` call
site (`{{name.pascalCase()}}Uri.swift`'s `static let resource = "{{name.paramCase()}}"`),
since that call already exercises the same helper mason will use for the new
`deepLinks` pattern:

| Partition | Input | `paramCase()` output (measured) | Matches K10.3 `^[a-z0-9-]+$`? |
|---|---|---|---|
| one word | `Payments` | `payments` | yes |
| two words | `PaymentHistory` | `payment-history` | yes — no underscore, no uppercase (pins the brief's mandated case) |
| acronym-leading | `QRScanner` | `q-r-scanner` (Mason's recase splits *each* capital letter as its own word — not `qr-scanner` as might be assumed) | yes — cosmetically surprising (3 segments instead of 2) but still all-lowercase-plus-hyphen, so no rule violation |
| digit-bearing | `Payments2` | `payments2` | yes |
| very short | `Ab` | `ab` | yes |

**No feature name in these partitions produces a K10.3-violating pattern.**
`paramCase()` only lowercases and inserts `-` at word boundaries; it never
emits `_`, uppercase, or (for any realistic non-empty PascalCase input)
leading/trailing/double hyphens. An empty `name` is not reachable through
normal use — `brick.yaml` prompts for it and an empty value breaks package
naming long before the deep-link pattern matters.

**Collision (K10.1):** the pattern and the Swift package name
(`Features/<PascalCase name>`) are derived from the same `name` variable. Two
generations can't produce two different packages sharing one pattern: Mason
hits a file conflict on `Features/<Name>/...` for a repeat name (prompts /
skips / overwrites under `--on-conflict`, never silently creates a second
package), and Tuist independently refuses two SPM products with the same
module name. So a *new*, distinct pattern is only produced for a genuinely
unique name — collision is prevented by construction, confirmed live in
Scenario 4 (two newly generated features, `Payments` and `PaymentHistory`,
coexisting with `Scanner`/`Settings` — K10.1 stayed green).

**Removal:** `ios_remove_feature` deletes `Features/<Name>/` wholesale (which
contains `RouteProvider.swift`, hence `deepLinks`), plus the four
marker-region lines (`Tuist/Package.swift`, `Project.swift`,
`AppComposition.swift` import + registration). Because `deepLinks` is
discovered by ArchTests via an AST scan of source files — not via any
separate marker-region registry — adding it introduces nothing for removal
to orphan. Confirmed live in Scenario 6: `git status` after removal was
byte-identical to the pre-generation baseline for every touched file.
`ios_remove_feature` needed no change, confirming the brief.

**Conclusion: no boundary/equivalence-partition feature name generates a
K10-violating pattern.** `paramCase()` is safe across every tested partition.

---

