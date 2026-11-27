---
name: trello-task
description: Write a new Trello task card by interviewing the user first (outcome, audience, scope, open questions) so nothing in the card is invented, then push it to one of the user's boards. Also reviews existing cards against the same standard. Use when the user says "crea una tarjeta de Trello", "publica una tarjeta", "agrega esto al backlog", "revisemos las tarjetas", "create a Trello card", "review the cards on the board", or describes work that should become a ticket. For moving or commenting an EXISTING card, use the trello skill instead.
---

# Write a Trello card: interview first, then write, then push

A card is a promise to the team about what will exist when the work is done. It
has to come from the user's head, not from yours. **Interview first, write
second, push last.**

The one rule everything else follows from: **nothing goes on the card that the
user didn't say or confirm.** No plausible details, no invented numbers, no
"obvious" sub-features, no deadline you picked. If you need something and don't
have it, ask; if the user doesn't know yet, that is an *open question* on the
card, not a blank for you to fill.

## Step 1 — Interview (before writing anything)

Ask these in the **language of the conversation**, **one at a time**, so each
answer can reshape the next question. Skip any the user already answered; never
ask one just to complete the set. If the host offers a structured question tool,
use it; plain chat is fine too. Group them into one message only if the user asks
for that.

1. **Outcome.** When this is done, what can someone do or see that they can't
   today? Who is that someone (a student, a client, a teammate, the team)?
2. **Why now.** What prompted it: a meeting, a request, a bug, a deadline, a
   roadmap milestone? Is there a date this is tied to, and whose date is it?
3. **Edges.** What is explicitly *not* part of this? Is it one change, or several
   that happen to be related?
4. **Unknowns.** Is anything undecided, waiting on someone, or blocked (data
   access, a decision, a document)? Who unblocks it?
5. **Done.** How would you check it's done? What would you click or look at?

These are high-level on purpose. Their job is to give the user room to explain
what they actually want to build, and to surface the parts that are still
undecided, before a draft locks a wrong idea into words.

Then listen. The user's answers often change the card's shape: one card becomes
two, a "feature" turns out to be a decision, a deadline turns out to be someone
else's. Reflect that back in a sentence before drafting ("so this is really two
things: the data load, and the screen that shows it. One card each?").

If an answer is "I don't know" or "not decided": that is a real answer. It goes
on the card as an **Open** line, and, if the board has labels for it (questions,
blocked), the card gets one. Never resolve it yourself and never create labels
on your own.

## Step 2 — Draft the body

**Language:** write the card in the language the board already uses (look at a
few existing cards with the `trello` skill's `cards` / `show`). If the board is
empty or mixed, ask once. Translate the section headings too (in Spanish:
**Contexto**, **Solución**, **Criterios de aceptación**, **Abierto**).

Use this structure:

**Title** — short, outcome-focused, no technical wording.

**Context/Problem:** 1–2 sentences on the motivation or goal, from the user's
answers to 1 and 2. It does NOT have to describe a problem; an opportunity, a
demo or the purpose of the feature is fine.

**Solution:** 1–3 bullets describing the feature from a user or product
perspective, from answer 1 bounded by answer 3. No implementation, services,
endpoints, refactors or data contracts.

**Acceptance Criteria:** 2–5 short outcome statements, from answer 5: what the
user can see, experience or do once this is complete. Simple sentences, not
checkboxes.

**Open:** (only if answer 4 produced any) one line per undecided point, naming
who decides it.

Rules:

- Brief and direct. Plain language. Under 130 words.
- Visible behavior and business outcome, not how it's built. Never mention
  APIs, endpoints, refactors, services, database changes or plumbing.
  *Exception:* infrastructure or experimental cards may name the systems
  involved when that **is** the outcome (an alert, a log, a tool). Even then,
  keep the acceptance criteria about what someone observes.
- One card per independent change. If the interview showed several, **propose**
  the split and let the user confirm; don't split silently.
- **Show the draft before pushing, with an `Assumed:` list under it** (`Asumido:`
  in Spanish) naming every sentence the user didn't say in so many words (an
  inferred date, a paraphrase that adds a detail, a label you chose). If that
  list is empty, say so. The user strikes or confirms each item. Anything struck
  comes off the card.
- **The draft has to be visible where the user answers.** If you ask for the
  approval through a question dialog (a structured question tool), the dialog
  covers the chat, so a body shown in the message above it is invisible. Put
  the full body inside the dialog itself: in the option preview, or in the
  question text if there is no preview. Never ask "does the body above look
  right?" from a dialog. One draft per dialog; the other values can go in a
  later one.

## Step 3 — Board and values

### Which board — ask, never assume

Run `python ~/.claude/skills/trello/scripts/trello_update.py boards` to see every
board the user can write to. The `TRELLO_BOARD_ID` default in their credentials
is a **fallback, not the answer**: if the user names a board, prefix the command
with `TRELLO_BOARD=<short id or name>`. If they have more than one board, none is
named, and the subject doesn't make it obvious, **ask**. Getting this wrong means
the user moves the card by hand. Match boards on short id, never on name.

### The values — ask for what's missing, offer live options

Run `TRELLO_BOARD=… trello_update.py board` first and offer the **live** lists,
labels, members and custom fields. Nothing about a board is assumed.

1. **List.** New cards go to the board's first backlog-like list unless the user
   says otherwise. Never file a new card in a done list.
2. **Label(s).** Offer the labels that exist on the board. If the user wants one
   that doesn't exist, create it first with the `trello` skill's `new-label`
   (name and color as the user says them), then use it. Never create a label
   the user didn't ask for.
3. **Custom fields.** Only if `board` shows them. `--effort` and `--priority`
   work when the board has fields named `Effort (1-10)` and `Priority`; their
   values are the user's call. If they shrug, leave them empty; don't estimate.
4. **Due date**, ISO 8601. Only set one the user gave or tied to something in
   answer 2 ("para el comité del jueves", "before the pilot"). A relative phrase
   ("next Friday", "en dos semanas") you convert from today's date and list under
   `Assumed:`. **No hint at all means no due date**, and you say so; a made-up
   due date is the most common invented fact on a board.

   Dates land in Trello as UTC. Pick the local time the user means (end of the
   workday unless told otherwise), convert it, and pass the full timestamp, e.g.
   `2026-12-04T21:00:00.000Z` for 18:00 at UTC-3 (Chile); a bare date shows as
   the previous evening there.

## Step 4 — Push and report

Same credentials and CLI as the `trello` skill (`~/.config/trello/credentials`;
`python ~/.claude/skills/trello/scripts/trello_update.py setup` walks through
anything missing). Standard library only, no venv. Never hand-roll REST calls,
never put a key or token on a command line.

Pass the body on stdin so no quoting mangles it:

```bash
TRELLO_BOARD=<short id> python ~/.claude/skills/trello/scripts/trello_update.py create \
  "Título corto orientado al resultado" \
  --list "<live list>" \
  --label "<live label>" \
  --due 2026-12-04T21:00:00.000Z \
  --desc - <<'BODY'
**Contexto:**
…

**Solución:**
- …

**Criterios de aceptación:**
…

**Abierto:**
…
BODY
```

`create` resolves every list, label and custom-field id **by name against the
board it writes to**, so it works on any board.

Report what `create` prints: short URL, **which board**, list, labels, custom
fields, due date, plus the `Assumed:` items the user accepted. Details that
don't fit the body (links, meeting notes, numbers) go in a **comment** on the new
card, through the `trello` skill's `comment`.

## Review mode: existing cards against the same standard

When the user asks to review, clean up or audit cards, read them first
(`cards`, then `show <card> --comments 5` for each), and grade each one on:

- **Outcome stated?** Does Context + Solution say what someone can do or see,
  and for whom? Or is it a task list in disguise?
- **Invented details?** Numbers, dates, sub-features or behaviors that look
  plausible but the user never asked for. Flag them; don't assume they're wrong.
- **One thing?** Would it ship as one piece, or is it two cards (or a card plus
  a decision)?
- **Open vs. decided.** Are undecided points marked as such (`Open:` line or a
  label), or buried in acceptance criteria as if settled?
- **Still true?** Does it match what the user now knows (list, assignee, due
  date, approach)? Comments often say the plan moved on and the body didn't.
- **Voice.** Product-facing, in the board's language, under 130 words, no
  plumbing (with the infrastructure exception above).

For each card give one verdict: **keep**, **touch up** (fields only),
**rewrite**, **split**, or **archive**, with the one-line reason and the
questions only the user can answer. Show the card's **current body** with the
verdict, and the **proposed body** next to any rewrite, so the user judges text,
not your summary of it. When the question goes through a dialog, both bodies go
in the dialog's previews (the same rule as in Step 2). Go **card by card**:
present one card's verdict, ask its questions one at a time the way Step 1 does,
apply what the user confirmed, then move to the next. Apply **only what the user
confirmed**, through the `trello` skill's commands (`desc --set`, `label`, `due`,
`field`, `assign`, `move`, `archive`), and `create` here for any split-off card.
Archive, never delete: Trello has no undo and archived cards can be brought back.

## Rules

- **Boards are usually shared.** A card is visible to everyone the moment it
  exists, under the token owner's name. Never push a body the user hasn't seen,
  and never push with `Assumed:` items still unanswered.
- Nothing on the card the user didn't say or confirm. An open point is an
  `Open:` line, not a guess.
- One card per independent change; propose splits, don't make them silently.
- Moving, commenting and editing cards is the `trello` skill's job; this skill
  only decides *what* the card should say.
