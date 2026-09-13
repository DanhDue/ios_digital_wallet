---
id: "task_14_deeplink_docs"
status: "done"
priority: "medium"
assignee: null
epic: "ios_deeplink_router"
dueDate: null
created: "2026-09-10T03:42:16+07:00"
modified: "2026-09-11T16:21:58+07:00"
completedAt: "2026-09-11T16:21:58+07:00"
labels: ["docs", "architecture", "governance"]
order: "a14"
---

# Task 14: Documentation — DEEPLINK.md and Updates

## Epic Reference
Epic: [ios_deeplink_router](../epic/ios_deeplink_router/ios_deeplink_router.en.md)

## Requirement Analysis

The subsystem is only usable if a feature author can add a deep link without
reading `Platform`'s source, and only defensible if the governance table names
its new rule.

**New — `docs/architecture/DEEPLINK.md`:**

1. **The URL grammar** — normalisation rules (custom scheme keeps the host as the
   first segment, `https` discards it), pattern syntax, parameter precedence
   (path beats query), duplicate query keys (last wins).
2. **How a feature declares deep links** — a copy-pasteable `deepLinks` example
   with the parent-chain convention: the first element of a built stack is the
   feature's entry route, which the router drops when it is that tab's root.
3. **Guard and tab-resolver contracts** — what the host implements, the invariant
   that a redirect target must itself be reachable without auth, and the fact
   that the router evaluates a redirect target only once.
4. **Pending and replay** — one link, no TTL, newer supersedes older; the
   consumer's obligation to publish `UserLoggedIn` when sign-in succeeds.
5. **The gating asymmetry** — the guard runs on deep-link entry only; tapping a
   tab is never gated, and that seam is `ShellViewModel`, not this subsystem.
6. **Enabling Universal Links** — the three steps (associated-domains
   entitlement, `apple-app-site-association` file,
   `onContinueUserActivity` forwarding into the same `open(_:)`), and the
   statement that no code change is required.
7. **K10** — what CI will reject and why.

**Updates:**

- `docs/architecture/ARCHITECTURE.md` — remove the "Deep-link / state
  restoration" row from §VII **Known gaps**, replacing it with a
  state-restoration-only row; add **K10** to the governance table; document
  `AnyAppRoute` in the navigation section.
- `README.md` — one line under "Add a feature" about the generated `deepLinks`,
  and the `xcrun simctl openurl` smoke command.
- `AGENTS.md` and `PROJECT_RULES.md` — one rule each: a route promoted to
  `AppRoutes` must declare a deep-link pattern (K10.2).

## Relevant Files & Context Pointers

- `docs/architecture/DEEPLINK.md` — **new**
- `docs/architecture/ARCHITECTURE.md` — §VII known gaps, §VI governance table, navigation section
- `README.md` — "Add a feature", project layout tree, quick start
- `AGENTS.md` — "Coding guidelines for agents"
- `PROJECT_RULES.md` — "Architecture & design"
- `docs/architecture/NETWORKING.md` — the structural model to follow for a new architecture doc
- `docs/LOCALIZATION.md` — the other worked example of a subsystem doc

## Design Rationale

- **Follow `NETWORKING.md`'s shape.** The repo already has a convention for a
  subsystem document: problem, contract, worked example, governance, gaps. A new
  doc that invents its own structure is harder to navigate and harder to keep
  current.
- **Remove the gap row, do not annotate it.** `ARCHITECTURE.md` §VII currently
  lists deep link and state restoration together. Splitting them keeps the
  remaining gap honest instead of leaving a half-true entry.
- **The consumer obligations must be stated as obligations**, not as prose: the
  guard's redirect target, the `UserLoggedIn` publisher, and the tab placement
  for a feature that owns a tab are three things a consuming project *must* do,
  and each is invisible until it silently does not work.
- **Document what the template deliberately does not ship** — no auth feature, no
  gated route, no Universal Links entitlement — so a reader does not mistake an
  intentional boundary for an unfinished one.
- Applicable skills in `.agents/skills/`: none directly; follow
  `elements-of-style:writing-clearly-and-concisely` conventions if available.

## TDD Checklist

**TDD Adaptation:** documentation has no runtime behaviour to drive RED-first.
Replaced with concrete, verifiable steps — every code sample must compile and
every command must be executed — so the doc cannot drift from the implementation.
The substitution is stated rather than silently dropped.

- [ ] Write `DEEPLINK.md` covering all seven sections above.
- [ ] **Verify every code sample compiles** by pasting it into a scratch target
      or a feature package and building; samples that only look right are the
      standard failure mode of architecture docs.
- [ ] **Execute every command shown** (`xcrun simctl openurl …`) and confirm the
      documented outcome.
- [ ] Update `ARCHITECTURE.md`, `README.md`, `AGENTS.md`, `PROJECT_RULES.md`.
- [ ] Re-read §VII to confirm no other row became stale during this epic.

## Definition of Done

- [ ] `docs/architecture/DEEPLINK.md` exists and covers all seven sections.
- [ ] Every code sample in it has been compiled; every command has been run.
- [ ] `ARCHITECTURE.md` §VII no longer lists deep linking as a gap; state
      restoration remains listed on its own.
- [ ] `ARCHITECTURE.md` governance table includes **K10.1–K10.6** (the rule grew during the epic; see carried note 4).
- [ ] `AnyAppRoute` is documented in the navigation section, including why
      erasure was necessary.
- [ ] `README.md`, `AGENTS.md` and `PROJECT_RULES.md` updated; every internal
      link in the touched files resolves.
- [ ] The three consumer obligations (redirect target, `UserLoggedIn` publisher,
      `TabPlacement`) appear as an explicit list, not buried in prose.

## Carried notes from later tasks' reviews — all four must land somewhere in the docs

1. **`UserLoggedIn` carries an unstated ordering obligation** (from Task 8's review).
   `AppEvent.swift` tells a consuming project to publish it "when sign-in
   succeeds", but never says **the access token must be written to
   `SessionManaging` before the event is published**. Delivery is deferred one
   main-queue turn and `SessionDeepLinkGuard` reads the session live, so
   publishing first makes `drainPending()` re-evaluate against an empty session
   and redirect again — the link is re-retained and recoverable, but the user sits
   on the redirect screen with no indication why. No test can ever catch this; it
   is the one obligation handed entirely to consumers. It costs one sentence.

2. **`DeepLinkPattern.swift`'s doc comment is factually wrong** (from Task 10's
   review). It currently claims K10.3 "walks `segments` — the same parsing this
   type already does ... rather than re-deriving the split/classify logic itself".
   ArchTests deliberately does **not** depend on `Platform`, so K10.3 and K10.5
   re-derive the split locally. There are two hand-maintained copies with nothing
   keeping them in sync: if `DeepLinkPattern.init` ever changes
   `omittingEmptySubsequences`, or adds case-folding or decoding before the split,
   ArchTests drifts silently. Fix the comment to say what is true, and document
   the duplication so the next person to change the parser knows to change both.

3. **Scaffolding a feature touches more files than anything documents** (from
   Task 11). `mason make ios_mvi_feature` also dirties both
   `Localizable.xcstrings` catalogues, the four `backend_translations` JSON files,
   `Translations.generated.swift`, and `Tuist/Package.resolved` — none of which
   appear in the brick's checklist or in README's "Add a feature". They all return
   to baseline when the feature is removed, so round-trip cleanliness holds; the
   gap is disclosure. A developer reviewing the resulting diff should not be
   surprised by six files they did not expect.

4. **K10 grew from three rules to six.** The governance table must list
   **K10.1–K10.6**, not K10.1–K10.3: K10.4 pins that the app entry point still
   wires `.onOpenURL` to `deepLinkRouter.open`; K10.5 rejects a pattern that
   declares the same parameter name twice; K10.6 rejects any non-literal pattern
   argument, which is what stops an interpolated or variable-built pattern
   silently vanishing from K10.1/K10.3/K10.5.

## Dependencies & Blockers

- Blocked by [Task 8](task_8_host_deeplink_wiring.md) — samples must match the
  final host API.
- Blocked by [Task 10](task_10_archtests_k10.md) — the K10 section documents
  rules that must already exist.
- Related: [Task 12](task_12_rename_script_scheme.md) rewrites the scheme inside
  `DEEPLINK.md`; land this task first so that path exists.

## References & Rollback

- Verification record captured at implementation time: [task-14-deeplink-docs.md](../epic/ios_deeplink_router/bdd/task-14-deeplink-docs.md)
- Source Spec §11 (documentation deliverables), §4 (contracts being documented).
- `docs/architecture/NETWORKING.md`, `docs/architecture/REFRESH_TOKEN.md` — the
  structural precedents.
- **Rollback**: documentation-only; no product behaviour is affected. Reverting
  leaves the subsystem working but undocumented, which should be treated as a
  release blocker rather than an acceptable state.
