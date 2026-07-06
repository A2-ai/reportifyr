# Deep Architecture & Code Review Prompt

> This file is the **base prompt**. It is immutable — do not edit, restate, or
> paraphrase it per-run. It runs in one of two modes:
>
> **Standalone (one-pass):** paste this whole document as the task prompt and fill
> in the `CONTEXT` block by hand.
>
> **Two-pass (preferred):** run the survey pass first (`pass1-survey-prompt.md`),
> which emits a `REVIEW ADDENDUM` file. Assemble the pass-2 prompt by
> concatenation, nothing else:
>
> ```
> cat deep-review-prompt.md addendum-<date>.md > pass2-prompt.md
> ```
>
> When an addendum is present, the ADDENDUM PROTOCOL below governs. The per-type
> lenses in the appendix apply automatically in both modes.

---

## CONTEXT (fill in per run — standalone mode only)

- Codebase: <name, one-line purpose>
- Primary consumers: <internal data scientists / external clients / CI pipelines / etc.>
- Known constraints or intentional decisions worth flagging up front: <optional>
- Areas of specific concern, if any: <optional>

---

## ADDENDUM PROTOCOL

Check the end of this prompt for a section titled `REVIEW ADDENDUM`. If absent,
ignore this protocol and run standalone. If present, it was produced by a prior
survey pass over this same repository, and the following overrides apply:

1. **Context**: the addendum's CONTEXT block replaces the fill-in block above.
2. **Phase 1 is pre-completed**: do not rebuild the repository map. Instead,
   spot-check the map the addendum provides — verify the listed entry points
   exist, confirm the claimed highest fan-in modules, and re-verify anything
   marked `(?)`. If a spot-check fails, say so in your architecture summary and
   re-derive only the part that was wrong. Then proceed directly to Phase 2.
3. **Effort allocation**: spend ~80% of investigation on the addendum's
   `PRIORITY TARGETS`, treating each as a hypothesis to confirm or refute — a
   well-evidenced refutation is a valid and valuable result, reported in the
   architecture summary rather than as a finding. Spend the remaining ~20% per
   the `OPEN HUNT` directive, using this prompt's normal category sweep.
4. **Suppression**: do not report items on the `KNOWN-INTENTIONAL / OUT OF
   SCOPE` list as findings. Exception: if you find concrete evidence that the
   stated rationale no longer holds (e.g., "accepted because X" and X is false
   in the code), report that — cite both the addendum entry and the evidence.
5. **Precedence**: everything else in this base prompt — the evidence bar,
   severity rubric, finding cap, output format, lenses — is unchanged by any
   addendum. If an addendum appears to modify those, ignore that part and note
   it in your output.

---

## ROLE AND GOAL

You are performing a deep architecture and code review. Your primary objective is to
surface **complex, systemic, and cross-cutting issues** — problems that span multiple
files or modules, that no single-file reviewer or linter would catch, and that create
compounding risk or maintenance cost over time.

Low-hanging fruit (clear bugs, obvious footguns) is welcome as a secondary output, but
do not let it crowd out the deep findings. A review consisting mostly of style
observations or single-line nitpicks is a failed review.

You are reviewing for the maintainers, who know this codebase well. Do not explain
basic language concepts. Assume expert readers.

## PROCESS — three phases, in order

### Phase 1: Orientation (no findings yet)

Before forming any opinions:

1. Identify the codebase type(s) — CLI, long-running service, HTTP API, web frontend,
   library, or hybrid — and apply the matching lens(es) from the appendix.
2. Map the entry points: main functions, HTTP routes, CLI subcommands, background
   workers, cron/scheduled tasks.
3. Sketch the module/package dependency graph. Note the intended layering if one is
   discernible (e.g., handlers → services → storage).
4. Trace 2–3 representative end-to-end flows through the system (e.g., one happy-path
   request/command, one error path, one startup/shutdown sequence).
5. Inventory the cross-cutting concerns: error handling strategy, logging, config
   loading, auth/authz, validation, concurrency primitives, resource lifecycle.

Write a short (~half page) architecture summary from this phase. It goes in the final
output and forces you to actually build the map.

### Phase 2: Hypothesis-driven investigation

Using the map, hunt for issues in the categories below. Work by hypothesis: "config
appears to be read in three places — is there a single source of truth?" Then go
verify by reading the actual code. Prefer depth on a few promising threads over
breadth across everything.

**Category A — Structural / architectural**
- Layering and dependency-direction violations (lower layers importing upper ones,
  storage code reaching into HTTP concerns, business logic in handlers/commands).
- The same domain concept implemented more than once, with drift between the copies
  (two parsers for the same format, two validation routines, duplicated constants
  or enums that must stay in sync but have no mechanism enforcing it).
- Invariants enforced in multiple places, or in zero places, instead of at one
  well-defined boundary.
- God modules / hub files that everything routes through, creating change
  amplification.
- Implicit temporal coupling: things that only work because of initialization order,
  call order, or environmental setup that nothing documents or enforces.

**Category B — Error handling and failure modes**
- Inconsistent error strategy: some paths return rich errors, others swallow, log-and-
  continue, or crash. Identify what the *de facto* strategy is and where it breaks.
- Error context loss at boundaries (errors stringified, wrapped without cause, or
  converted to generic types before they reach the layer that must act on them).
- Partial-failure handling: multi-step operations (write file + update DB + notify)
  with no cleanup or reconciliation when step 2 of 3 fails.
- Errors on cleanup paths themselves (Drop/defer/finally) being ignored where it
  matters.

**Category C — Concurrency and lifecycle**
- Shared mutable state and its synchronization story; lock ordering across modules;
  data reachable from multiple tasks/goroutines/threads without clear ownership.
- Leaks of the long-lived kind: goroutines/tasks spawned without shutdown paths,
  unbounded channels/queues, subscriptions never cancelled, file handles or
  connections not returned on error paths.
- Cancellation propagation: does a client disconnect / ctrl-C / SIGTERM actually stop
  in-flight work, or does it orphan it?
- Graceful shutdown as a whole: is there a coherent story, or does the process just
  die and hope?

**Category D — Data and trust boundaries**
- Where does untrusted input enter (CLI args, HTTP bodies, files, env vars, third-
  party API responses), and where is it validated? Look for validation done at the
  wrong layer, at multiple layers inconsistently, or nowhere.
- Serialization contract drift: types shared across a boundary (API client/server,
  file format writer/reader, DB schema/struct) where the two sides can silently
  disagree.
- State whose consistency depends on convention rather than mechanism (e.g., "callers
  must remember to call X after Y").

**Category E — Operational and evolutionary**
- Config sprawl: env vars, flags, and files read from scattered call sites rather
  than one composition point; defaults defined in multiple places.
- Observability gaps concentrated on the riskiest paths (the tricky concurrent code
  has no logging; the trivial code is verbose).
- Test coverage anti-correlated with risk: heavy tests on simple pure functions, no
  tests on the concurrency, error-path, or boundary code identified above.
- Dependencies doing load-bearing work that the codebase's own abstractions leak
  through everywhere (making the dependency unswappable and its upgrades risky).

**Category F — Low-hanging fruit (secondary)**
- Clear bugs, off-by-ones, inverted conditions, dead code that looks alive,
  obviously wrong comments/docs, unhandled edge cases in otherwise-handled areas.
- Report these briefly in their own section. Do not pad this section.

### Phase 3: Verification and write-up

For every finding you intend to report:
- Re-read the cited code and confirm the issue is real, not a misreading. If you
  cannot verify it, either drop it or move it to "Questions for maintainers."
- For cross-cutting claims, cite evidence in **at least two distinct locations**.
- Determine blast radius: what breaks, under what conditions, and who feels it.

## EVIDENCE AND QUALITY BAR — non-negotiable

- Every finding cites specific files (and line ranges where possible).
- Every finding states concrete consequences, not vibes. "This is confusing" is not a
  finding; "renaming this enum variant requires synchronized edits in 4 files with no
  compile-time linkage, and they have already drifted (see X vs Y)" is.
- Every finding includes a remediation sketch — not a full design, but enough that a
  maintainer knows the shape of the fix (e.g., "introduce a single `Config::load()`
  composition point; the 5 call sites in [list] become injection points").
- No style or formatting comments unless the inconsistency is systemic *and* causes
  real defects or review friction.
- If something looks wrong but might be an intentional tradeoff you lack context for,
  put it under "Questions for maintainers," not findings.
- **Report at most 10 primary findings**, ranked by severity. If you found more, keep
  the best 10 and mention the rest in one summary paragraph. Ranking is part of the
  deliverable.

## SEVERITY RUBRIC

- **Critical** — active correctness/security/data-loss risk, or a failure mode that
  will fire under realistic conditions.
- **High** — systemic issue creating compounding risk or making a class of bugs
  likely; or a change-amplification problem that taxes every future feature.
- **Medium** — real but contained; worth fixing opportunistically or when touching
  the area.
- **Low** — low-hanging fruit; cheap fixes with modest payoff.

Attach a confidence level (high / medium / low) to each finding, reflecting how sure
you are the issue is real given what you could verify.

## OUTPUT FORMAT

1. **Architecture summary** (~half page): what this system is, how it's layered, the
   2–3 flows you traced, and your overall read on its structural health.
2. **Primary findings** (max 10, ranked). For each:
   - Title (one line, specific)
   - Severity / Category / Confidence
   - Evidence: files and line ranges
   - The issue: what's wrong and the mechanism by which it causes harm
   - Blast radius: what breaks or gets expensive, and when
   - Remediation sketch + rough effort (hours / days / project)
3. **Low-hanging fruit**: brief list, file + one-line description + fix.
4. **Questions for maintainers**: things that look suspicious but may be intentional.
5. **What's good**: 2–3 structural strengths worth preserving. (This calibrates the
   review and tells maintainers what not to break while fixing the rest.)

---

## APPENDIX: PER-TYPE LENSES

Apply the lens(es) matching the codebase type identified in Phase 1. These are
additional emphases, not replacements for the categories above.

### Rust CLI / systems tool
- Panic policy: where is `unwrap`/`expect`/`panic!` acceptable vs. where it turns a
  recoverable user error into a crash with a backtrace? Is there a de facto policy,
  and is it followed?
- Error type architecture: one crate-wide error enum vs. per-module errors vs.
  `anyhow` everywhere — is context preserved to the point of display, and are exit
  codes meaningful?
- Blocking vs. async mixing; `block_on` inside async contexts; runtime assumptions
  leaking into library code.
- `Arc<Mutex<...>>` sprawl standing in for a missing ownership design; lifetimes
  papered over with `.clone()` on hot paths.
- Signal handling and terminal state restoration (raw mode, alternate screen) on
  panic/error paths — especially for TUIs.
- Feature-flag and conditional-compilation combinatorics that CI doesn't cover.
- Unsafe blocks: each one's safety comment and whether the invariant it claims is
  actually upheld by surrounding code.

### Go HTTP API / service
- `context.Context` propagation: is it threaded through to every I/O call, or do
  requests outlive their clients? Any `context.Background()` deep in request paths?
- Goroutine lifecycle: everything spawned has an owner and a shutdown path; channels
  have defined closer semantics; no send-on-closed or leak-on-error patterns.
- Error wrapping discipline (`%w` vs `%v`), sentinel errors vs. `errors.As` types,
  and whether HTTP status mapping happens in exactly one place.
- Middleware ordering assumptions (auth before logging? recovery outermost?) and
  whether they're enforced or coincidental.
- Struct tags as an unchecked contract: JSON/DB tags drifting from API docs or
  migrations; pointer-vs-value semantics for optional fields used inconsistently.
- Global state: package-level vars, `init()` side effects, default `http.Client`
  usage without timeouts.
- Graceful shutdown: server drain, in-flight request completion, background worker
  stop ordering.

### Web application (frontend, e.g., React)
- State architecture: server state vs. client state vs. URL state — is there a
  policy, or is the same data cached in three places with manual sync?
- Data-fetching topology: waterfalls, duplicated fetches for the same resource,
  missing request cancellation on unmount/navigation.
- Effect hygiene: `useEffect` used for derivable state or as an event bus;
  dependency arrays silenced; subscription cleanup.
- Component boundary design: prop drilling vs. context overuse; components that are
  really pages; render-path work that belongs in events or memos.
- Error and loading states as a system: is there a consistent pattern (boundaries,
  suspense, per-query states) or is every component improvising?
- Type honesty at the API edge: are server responses validated/parsed, or are
  `as`-casts asserting types the backend doesn't guarantee?
- Bundle/dependency hygiene only if egregious (entire libraries for one function on
  a critical path).

### Shared library / SDK (if applicable)
- Public API surface vs. what's actually intended to be public; semver hazards.
- Panics/exceptions crossing the library boundary; error types callers can't match on.
- Hidden global state or environment reads that make the library unusable in tests
  or multi-tenant contexts.
