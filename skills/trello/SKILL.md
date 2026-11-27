---
name: trello
description: Update existing Trello cards on any of the user's boards — move a card, comment progress, tick checklist items, set labels/assignees/due/custom fields, or load a card as the spec for a feature. Use when the user says "mueve la tarjeta X", "comenta en la tarjeta", "qué tengo pendiente", "trabajemos la tarjeta #12", "comment on card X", "move 12 to review", or names a Trello card. NOT for creating cards — that is the trello-task skill.
---

# Update a Trello card

Update **existing** Trello cards. This is for tracking progress and working a
specific feature — NOT for creating cards. If the user wants a new card, use the
`trello-task` skill instead.

## Setup (once per person)

Everyone uses their **own** Trello key and token, kept in
`~/.config/trello/credentials`, outside every repo, so they work from any checkout
and can never be committed. Every write lands under the token owner's name, so
never borrow someone else's token.

```bash
python ~/.claude/skills/trello/scripts/trello_update.py setup
```

`setup` walks through whatever is missing, in order:

1. **No credentials:** it prints the exact clicks on trello.com to get an API key
   and a token, and the commands that save them to the credentials file.
2. **No default board:** it lists every board the token can see, with short ids,
   and the exact command that sets `TRELLO_BOARD_ID` in the credentials file.
3. **All set:** it shows who the token belongs to and which board is the default.

Any other command stops with the same guidance when something is missing. When
that happens, show the user the output, let them run the commands that need their
key or token themselves, and never ask them to paste a token into the chat. Don't
go looking for a token anywhere else.

The script is **standard library only**, so there is no venv and no `pip install`:

```bash
python ~/.claude/skills/trello/scripts/trello_update.py <subcommand> ...
```

Never pass the key or token on the command line.

## Which board

Nothing is hardcoded. Each person sets their default as `TRELLO_BOARD_ID` in
`~/.config/trello/credentials`. To work on any other board, pass `TRELLO_BOARD`
for that one command. It takes the board's short id or any unique part of its name:

```bash
python ~/.claude/skills/trello/scripts/trello_update.py boards     # your boards + exact commands
TRELLO_BOARD=<short id or name> python ~/.claude/skills/trello/scripts/trello_update.py board
```

A card number can exist on more than one board and resolve to the wrong card. If
the user names a board, pass it with `TRELLO_BOARD`. If the user has several boards,
doesn't name one, and the subject doesn't make it obvious, ask. If `TRELLO_BOARD`
matches none or several boards, the CLI lists them: pick from that list, never
guess. Match boards on their short id, not their name (names change).

Run `... trello_update.py board` any time you need the current lists, labels,
members and custom fields. Run `--help` or `<subcommand> --help` for exact flags.
The script resolves list / label / member / custom-field ids **by name at call
time** for whichever board is targeted, so it works on any board. That matters:
two boards can have custom fields with the same name and different ids.

## Referring to a card

Every subcommand takes a card reference as its first argument. Accepted forms:

- short id — `12` or `#12`
- name substring — `"Actividades en Canvas"`
- short link or full URL — `VkI26b0H`, `https://trello.com/c/VkI26b0H`

Ambiguous name matches fail loudly with the candidate list — pick from it, don't
guess. If the user names a card vaguely, run `search` first and confirm which one
they mean before mutating anything.

## Subcommands

**Read**
- `search <query> [--list NAME] [--archived]` — find cards by name, description, or short id
- `cards [LIST]` — cards in one list, or every open list
- `mine` — cards assigned to the token's owner, grouped by list
- `wip` — the lists that look like work in progress or review (matched by name, English or Spanish)
- `show <card> [--comments N]` — full detail: list, labels, members, due, custom fields, description, checklists, recent comments
- `board` — lists, labels, members, custom fields

**Long text goes through stdin.** Every text argument (`comment TEXT`, `edit-comment --set`,
`desc --set` / `--append`, `create --desc`) takes `-` to read the text from stdin, so a body
is passed with a heredoc and never mangled by shell quoting:

```bash
python ~/.claude/skills/trello/scripts/trello_update.py desc <card> --set - <<'BODY'
…the whole description…
BODY
```

Empty text (or a lone `-`) is refused, and `desc` prints the description it wrote: read it
back before reporting.

**Write**
- `move <card> <list> [--comment TEXT] [--top|--bottom]` — move between lists
- `comment <card> "TEXT"` — post a progress note
- `edit-comment <card> (--set TEXT | --replace OLD NEW) [--id ID | --match TEXT]` — edit one of **your own** comments (Trello allows no other); defaults to your newest comment on the card. `show` prints each comment's id
- `desc <card> --append TEXT` / `--set TEXT` — edit the description
- `rename <card> "NEW TITLE"` — change the card's title
- `check <card> "ITEM"` / `uncheck <card> "ITEM"` — tick checklist items by substring (`--all` for every match)
- `add-items <card> "ITEM" ["ITEM"...] [--checklist NAME] [--checked]` — add checklist items, creating the checklist if needed
- `label <card> [--add NAME] [--remove NAME]` — repeatable flags; the label must already exist on the board
- `new-label "NAME" [--color COLOR]` — create a label on the board. **Only when the user asks for that label** (name and, if they care, color); never to make a card fit. It refuses a name that already exists. Colors: `green`, `yellow`, `orange`, `red`, `purple`, `blue`, `sky`, `lime`, `pink`, `black` (each also `_light` / `_dark`), or none. Labels show on the whole board, so confirm the exact name before creating one you're inferring
- `assign <card> [--add NAME] [--remove NAME]` — accepts full name or `@username`
- `due <card> [DATE|clear] [--complete|--incomplete]` — ISO 8601; infer `YYYY-MM-DD` from relative phrases using today's date and state the inferred date back
- `field <card> [--effort N] [--priority LEVEL]` — only if the board has custom fields named `Effort (1-10)` and `Priority` (check with `board`)
- `setup-fields` — create those two fields on the board: `Priority` (dropdown, colored: Highest red, High orange, Medium yellow, Low blue, Lowest sky, Not sure gray) and `Effort (1-10)` (number), both shown on the card front. **Only when the user asks** for priority or effort on a board that lacks them. A field that already exists is kept with its values; an existing `Priority` only gets those colors. Safe to run again
- `archive <card> [--unarchive]`

## Board conventions

Each board has its own lists. Read them with `board` and follow the flow they
imply (for example `Backlog` → `To Do` → `In Progress` → `Review` → `Done`); don't
assume names.

- Starting work → move to the board's in-progress list and assign yourself if you aren't already on it.
- Ready for review → move to the board's review/QA list, if it has one, and comment what changed and what to verify.
- Finished → move to the board's done list. If there are several (for example one per week), use the open one and never an archived list.
- Blocked → keep it where it is, add a blocked label if the board has one (if it doesn't, offer to create it with `new-label`; don't create it unasked), and comment why plus what would unblock it.

## Common flows

**Progress update.** `show` the card first so the note builds on what's already
there, then `comment` and tick any checklist items the work completed. If the
work finished a stage, move the card in the same pass.

**Working a feature.** When the user wants to work on a card, `show` it and use
the description and acceptance criteria as the spec for the implementation.
Restate the acceptance criteria back before starting so you're aligned. Read
**every** row of a checklist, including the ticked ones — a ticked row can still
carry open work in its body. When the work is done, come back and update the
card: comment what was built, tick the criteria if they're checklist items, and
move the list forward.

**End-of-day sync.** `mine` or `wip`, then update each card the user reports on.

## Writing comments

Progress comments are for the people on the board, so:

- Write them in **the language the board already uses** (look at recent cards and comments with `show`). If it's mixed or unclear, ask once and stick to it.
- Lead with status: what moved forward, what's left, what's blocked.
- Keep it to a few lines. No preamble, no restating the card.
- PR links, branch names and specific numbers are welcome here — comments are work-tracking, unlike descriptions.
- **News on an existing card goes in a comment, not the description.** A blocker, a changed plan or a new finding is a `comment`; the description stays as it was. Rewrite the description only when the user asks to change the card itself. The description is the agreed spec; comments carry what happened since.
- Descriptions stay product-facing in the `trello-task` voice: plain language, visible behavior, no endpoints or plumbing. If you `desc --append`, match that voice.

## Rules

- **Boards are usually shared.** Every write is visible to others immediately, under the token owner's name, and there is no undo. When the user's instruction is unambiguous ("mueve la 12 a Review", "comenta en la 8 que ya está desplegado"), just do it. When you're inferring the card, the target list, or writing a comment from your own read of the work, state the exact change you're about to make and confirm first.
- Never create cards here — that's the `trello-task` skill.
- Never edit or move a card the user didn't ask about, even if it looks stale.
- Batch related updates on one card into a single pass, then report once.
- After writing, report the card's short id, name, its board, its new list, and what changed.
