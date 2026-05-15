---
alwaysApply: true
---

# Code Quality

## Anti-defaults (counter common Claude tendencies)

- No premature abstractions. Three similar lines beats a helper used once.
- Don't add features or improvements beyond what was asked.
- Don't refactor adjacent code while fixing a bug.
- No dead code or commented-out blocks. Git has history.
- WHY comments, never WHAT. If code needs a "what" comment, rename instead.
- API docs at module boundaries only, not every internal function.

## Naming

- Files: PascalCase for all modules (`PlayerData.luau`, `UIManager.luau`).
- Variables/functions: camelCase. Services/classes: PascalCase.
- Booleans: `is` / `has` / `should` / `can` prefix. Functions: verb-first (`getPlayer`). Constants: `SCREAMING_SNAKE`.
- Abbreviations only when universally known (`id`, `userId`). Acronyms as words: `userId`, not `userID`.

## Code Markers

`TODO(author): desc (#issue)` for planned work. `FIXME(author): desc (#issue)` for known bugs. `HACK(author): desc (#issue)` for ugly workarounds (explain the proper fix). `NOTE: desc` for non-obvious context. Owner and issue link required. Never `XXX`, `TEMP`, `REMOVEME`.

## File Organization

- `require()` calls at the top of each module.
- Modules return a table (for a class/service) or a single function (for utilities).
- Public API first, then helpers in call order.
