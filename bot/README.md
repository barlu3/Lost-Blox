# Lost Blox Community Bot

Discord bot for community management and support (TASK_Q6_03).

## Commands

- `!bugreport <title> | <description>` — any member. Opens a thread in
  `#bug-triage` with the templated fields and reacts ✅ to confirm.
- `!lookup <roblox_username>` — **Support role only**, rate-limited to 5 uses per
  user per minute. Returns a player summary embed sourced from the live-ops
  Exporter cache (TASK_Q6_01), not the Roblox API directly.

Unknown commands are silently ignored.

## Setup

1. `pip install -r requirements.txt`
2. Create `bot/.env` (gitignored — never commit it) with:

   ```
   BOT_TOKEN=your-discord-bot-token
   GUILD_ID=000000000000000000
   DASHBOARD_LOOKUP_URL=http://localhost:8080/lookup
   PLACE_VERSION=live
   ```

3. `python lostblox_bot.py`

## Tests

`core.py` holds the testable logic (rate limiter, permission gate, bug-report
formatting, lookup) with no discord.py dependency:

```
python3 -m unittest discover -s bot -p "test_*.py"
```
