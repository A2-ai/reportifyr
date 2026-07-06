# Pass 1: Repository Survey & Review Targeting Prompt

> **File conventions** (adjust paths if your repo differs, but keep the roles):
>
> - `.review/deep-review-prompt.md` — the base deep-review prompt. **Read-only.**
> - `.review/pass1-survey-prompt.md` — this file.
> - `.review/survey-<date>.md` — your full output (sections 1–5 below).
> - `.review/addendum-<date>.md` — section 4 extracted into its own file, ready
>   for assembly.
>
> Pass 2 is assembled by the operator (or CI) with:
>
> ```
> cat .review/deep-review-prompt.md .review/addendum-<date>.md > /tmp/pass2-prompt.md
> ```
>
> The base prompt contains an `ADDENDUM PROTOCOL` section that consumes your
> addendum: it uses your CONTEXT block, treats your repo map as a pre-completed
> orientation (with spot-checks), honors your 80/20 priority-targets/open-hunt
> split, and suppresses your known-intentional list. Your addendum must therefore
> follow the exact schema in section 4 — the protocol depends on those section
> names (`CONTEXT`, `PRIORITY TARGETS`, `OPEN HUNT`, `KNOWN-INTENTIONAL / OUT OF
> SCOPE`, `REPO MAP`).
>
> You may read the base prompt to understand what Pass 2 will do with your
> output. You must never edit it, copy its rubric into your addendum, or emit an
> assembled pass-2 prompt yourself — assembly is pure concatenation, done outside
> this task.
>
> This pass does NOT produce review findings. It produces targeting.

---

## ROLE AND GOAL

You are performing the survey pass of a two-pass architecture review. Your job is
to index and understand this repository well enough to (a) brief a second reviewer
who has never seen it, and (b) propose where that reviewer's limited attention
should go. You are optimizing the *allocation* of a future deep review, not
performing one.

Resist the urge to report findings. Depth spent proving an issue here is depth
stolen from Pass 2. The one exception is the Parking Lot (below).

## WHAT TO PRODUCE

Two files: the full survey report (`.review/survey-<date>.md`, sections 1–5
below) and the extracted addendum (`.review/addendum-<date>.md`, section 4
only). Both must be self-contained — assume the Pass 2 reviewer starts with zero
context and cannot ask you anything, so every claim needs concrete file paths so
it can be re-verified.

### 1. Repository map

- Purpose of the system in 2–3 sentences; codebase type(s) (CLI / service / API /
  frontend / library / hybrid).
- Entry points with paths: mains, HTTP routes and where they're registered, CLI
  subcommands, background workers, scheduled tasks.
- Module/package inventory: one line per significant module — path, responsibility,
  approximate size, and its notable dependencies (internal and external).
- Intended layering, if discernible, and where you inferred it from.
- The 2–3 most load-bearing files/modules (highest fan-in, or on every request/
  command path), by path.
- Cross-cutting concern inventory with locations: where errors are defined and
  handled, where config is loaded, where logging is set up, where auth/validation
  happen, what concurrency primitives are in use and where.
- Build/test/CI shape in 3–4 lines: how it builds, what the tests cover at a
  glance, anything unusual in CI.

### 2. Risk hypotheses (ranked, max 8)

For each hypothesis about where deep problems likely live:
- **Hypothesis**: one sentence, specific and falsifiable ("the retry logic in
  `src/client/` and `src/worker/` appear to be independent implementations of the
  same policy and may have drifted").
- **Signal**: what you observed that suggests it — file paths, patterns, sizes,
  duplication, absence of tests. Cite at least one concrete location.
- **If true, cost**: what it breaks or taxes.
- **Investigation sketch**: what Pass 2 should actually do to confirm or refute it
  (which files to diff, which flow to trace, what to grep for).
- **Confidence**: high / medium / low that this is worth the dig.

Rank by expected value (likelihood × cost), not by how easy they were to spot.

### 3. Questions for the maintainer (max 10)

Each question must be:
- Tied to a specific hypothesis or targeting decision ("Q3 → hypothesis 2").
- Answerable in a sentence or two.
- Accompanied by a **default assumption** you will proceed with if unanswered.

Good questions distinguish intentional tradeoffs from accidents, or pick between
focus areas. Examples of the right shape:
- "`unwrap()` is common in the TUI event loop (e.g., `src/tui/events.rs`). Is
  there a panic-catching layer I'm not seeing, or is crash-on-error accepted
  here? Default: treat as accepted for the TUI, not for library code."
- "Modules X and Y both parse format Z. Is one deprecated? Default: treat both as
  live and review for drift."
- "Which matters more for this repo right now: correctness of the numerical core,
  or maintainability of the I/O layer? Default: correctness."

### 4. Pass 2 addendum (also written to its own file)

Write this section to `.review/addendum-<date>.md` as well as including it here.
The file must begin with the exact header:

```
## REVIEW ADDENDUM (survey pass, <date>)
```

The base prompt's ADDENDUM PROTOCOL matches on that header and on the section
names below — use them verbatim. Write the addendum so it is valid both before
and after maintainer answers (apply your stated defaults; mark each item a
maintainer answer could change with `[Q#]`). It contains exactly these sections:

- **CONTEXT**: the filled-in context block for the base prompt.
- **PRIORITY TARGETS**: the top 3–5 hypotheses translated into review directives,
  with their investigation sketches and file paths. Pass 2 allocates roughly 80%
  of review effort here.
- **OPEN HUNT**: name the areas or base-prompt categories this survey spent the
  least time on, so Pass 2's ~20% unanchored sweep counters your blind spots.
- **KNOWN-INTENTIONAL / OUT OF SCOPE**: decisions the review must not flag,
  each with its source (maintainer answer `[Q#]`, ADR, or in-repo comment).
  Only things with an actual source — no inferred intent.
- **REPO MAP**: section 1 pasted verbatim, with anything you were unsure about
  marked `(?)` so Pass 2 re-verifies rather than trusts it.

Do NOT restate or modify the base prompt's process, evidence bar, severity
rubric, finding cap, or output format. Those are fixed. The addendum only aims
them.

### 5. Parking lot (optional, brief)

Anything that looks clearly broken which you noticed *in passing* — one line
each, path + symptom. No investigation, no severity analysis, no padding. Pass 2
will triage these under its low-hanging-fruit section.

## CONSTRAINTS

- Breadth over depth everywhere except hypothesis signals, which need one
  concrete citation each.
- Reading budget: skim widely; read closely only what's needed to form and
  ground hypotheses. If you find yourself proving an issue, stop and write it as
  a hypothesis instead.
- Every path you cite must be real — you will not be available to correct the
  record in Pass 2.
- If the repo contains docs/ADRs/READMEs stating intent, read them early; they
  are the cheapest source of "intentional vs. accidental" and shrink the
  question list.
