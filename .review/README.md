# Deep Review Workflow — User Guide

How to run the two-pass architecture review against a repository.

## Contents of `.review/`

| File | Role |
|---|---|
| `deep-review-prompt.md` | Base review prompt. **Never edit per-run.** |
| `pass1-survey-prompt.md` | Survey/targeting prompt. **Never edit per-run.** |
| `survey-<date>.md` | Output of pass 1 (generated) |
| `addendum-<date>.md` | Targeting addendum (generated, then optionally edited by you) |
| `README.md` | This guide |

One-time setup: copy the two prompt files into `.review/` at the repo root and
commit them. Generated files can be committed too (recommended — they accumulate
useful history) or gitignored.

---

## Step 1 — Run the survey (fresh session)

Start a **new session** with the repo root as the working directory. Do not
reuse a session you've been coding in — leftover context biases the survey and
eats the budget. Kick off with:

```
Read .review/pass1-survey-prompt.md and execute it against this repository.
Write your outputs to .review/survey-<date>.md and
.review/addendum-<date>.md as the prompt specifies. When finished, print
the "Questions for the maintainer" section in chat so I can answer inline.
```

Let it run to completion. Expect a repo map, ranked risk hypotheses, a question
list, the addendum file, and possibly a short parking lot of things it noticed
in passing.

## Step 2 — Answer the questions (same session, ~5 minutes)

The questions arrive numbered, each with a default. Answer inline in chat —
short answers are fine, and you can skip any question (its default applies):

```
Q1: yes, intentional — glibc floor for client clusters.
Q2: silent drops are NOT acceptable, they must be counted.
Q3: skip.
Q5: focus correctness of the numerical core over the I/O layer.
Then update the addendum file with these answers and show me a diff.
```

Review the diff it makes to `addendum-<date>.md`. If you'd rather not interact
at all, skip this step entirely — the addendum is valid as-written with
defaults applied.

**End the session here.** The survey session's job is done once the addendum
file is final.

## Step 3 — Sanity-check the addendum (30 seconds, no agent)

Open `addendum-<date>.md` and check:

- Priority targets are the things *you'd* actually pay to have investigated.
  Delete or reorder freely — it's your targeting, the agent just drafted it.
- Known-intentional list contains nothing you actually want reviewed.
- It does not contain rubric language (severity definitions, output formats,
  process phases). If it does, delete those lines — the base prompt owns them
  and pass 2 is instructed to ignore them anyway.

## Step 4 — Assemble and run the deep review (fresh session — mandatory)

Assemble:

```
cat .review/deep-review-prompt.md .review/addendum-<date>.md > /tmp/pass2-prompt.md
```

**Clear context / start a brand-new session.** This is the most important rule
in this guide, for three reasons:

1. **Independence.** Pass 2 must verify the survey's claims from the code, not
   from memory of having made them. A reviewer that built the map will not
   genuinely spot-check the map.
2. **Budget.** The deep review is the expensive pass; it needs the full context
   window for reading code, not survey leftovers.
3. **No answer leakage.** Your interview answers should reach pass 2 only
   through the addendum text you approved, not through chat history.

Then kick off:

```
Read /tmp/pass2-prompt.md and execute it against this repository. Note the
ADDENDUM PROTOCOL section — an addendum is present. Write your full review to
.review/findings-<date>.md and give me the ranked findings summary in chat.
```

Do not chat with it mid-run beyond clarifications it asks for. In particular,
do not ask it to start fixing things — see step 5.

If the session compacts (long context gets summarized) partway through, quality
drops for whatever comes after. On very large repos, prevent this by splitting
pass 2 into two runs: priority targets 1–3 in one session, targets 4–5 plus the
open hunt in another, each with the same assembled prompt plus one line saying
which slice to do.

## Step 5 — Triage and fix (separate sessions per fix)

Read `findings-<date>.md` yourself first. Then:

- **Fixes get their own fresh sessions**, one per finding (or per small cluster
  of related findings). Kick off with the finding text pasted verbatim:
  "Here is a finding from an architecture review: <paste>. Verify it still
  holds, then implement the remediation sketch." A fixer that re-verifies is a
  second independent check on the reviewer.
- Never let the review session pivot into fixing. Review context is huge and
  mostly irrelevant to any single fix; you'll get sloppy edits and burn the
  session.
- Refuted hypotheses and the "What's good" section are worth reading — they
  tell you what not to break.
- Anything in "Questions for maintainers" that surprised you should either get
  a code comment/ADR (so the next survey finds the intent in-repo) or a line in
  the next addendum's known-intentional list.

## Re-running on a cadence

For the second and later reviews of the same repo, replace step 1's kickoff
with:

```
Read .review/pass1-survey-prompt.md. A previous survey exists at
.review/survey-<old-date>.md and previous findings at
.review/findings-<old-date>.md. Execute the survey prompt, but: diff your
findings against the old map rather than describing everything from scratch,
carry forward the known-intentional list, drop hypotheses that were refuted
last time unless new evidence appears, and note which prior findings look
fixed vs. still present.
```

Everything else is identical. Over time the interview shrinks to only
genuinely new questions.

## Quick reference

| Do | Don't |
|---|---|
| Fresh session for pass 1 | Run the survey in a coding session |
| Fresh session for pass 2 (always) | Run pass 2 in the survey session, even if context remains |
| Answer questions tersely; skip freely | Treat the interview as a discussion — it's a form |
| Edit the addendum by hand — it's yours | Edit the two base prompt files per-run |
| Assemble with `cat` | Ask an agent to "merge" the prompt and addendum |
| One fresh session per fix | Let the reviewer start fixing |

## FAQ

**Can I skip pass 1?** Yes. The base prompt runs standalone — fill in its
CONTEXT block by hand. Use this for small repos or quick checks; use two-pass
for anything you'd call a real review.

**How long does each pass take?** Survey: minutes to tens of minutes depending
on repo size. Deep review: longer — it's reading and tracing code. Start it
when you don't need the answer immediately.

**The deep review flagged something known-intentional anyway.** Check whether
it cited evidence that your stated rationale no longer holds — the protocol
allows exactly that override, and it's usually worth reading. If it's just
noise, add a sharper entry to the known-intentional list for next time.

**Can this run unattended (CI)?** Yes: pass 1 → skip interview (defaults
apply) → `cat` → pass 2, no human in the loop. Expect somewhat noisier
targeting than the interactive flow; the interview is cheap signal you're
giving up.
