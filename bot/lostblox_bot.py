"""Lost Blox community Discord bot (TASK_Q6_03).

Thin discord.py wiring over bot/core.py. Commands:
  !bugreport <title> | <description>   — any member; opens a #bug-triage thread
  !lookup <roblox_username>            — Support role only; rate-limited 5/min

Run: set BOT_TOKEN and GUILD_ID in bot/.env, then `python lostblox_bot.py`.
discord.py is imported lazily so the test suite can import core.py without it.
"""

from __future__ import annotations

import os
import urllib.request
import json

import core

DASHBOARD_LOOKUP_URL = os.environ.get("DASHBOARD_LOOKUP_URL", "http://localhost:8080/lookup")


def fetch_player(username: str):
    """Queries the live-ops Exporter cache for a player summary, or None."""
    try:
        with urllib.request.urlopen(f"{DASHBOARD_LOOKUP_URL}?username={username}", timeout=5) as resp:
            if resp.status != 200:
                return None
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def main() -> None:
    import discord
    from discord.ext import commands

    intents = discord.Intents.default()
    intents.message_content = True
    bot = commands.Bot(command_prefix="!", intents=intents)

    lookup_limiter = core.RateLimiter(limit=5, window=60)

    @bot.command(name="bugreport")
    async def bugreport(ctx, *, body: str = ""):
        title, _, description = body.partition("|")
        report = core.build_bug_report(
            title=title.strip() or "Untitled",
            reporter_tag=str(ctx.author),
            ingame_name="(unknown)",
            description=description.strip() or "(none)",
            place_version=os.environ.get("PLACE_VERSION", "live"),
        )
        channel = discord.utils.get(ctx.guild.channels, name=report["channel"])
        if channel is not None:
            thread = await channel.create_thread(name=report["thread_name"])
            await thread.send("\n".join(f"**{k}:** {v}" for k, v in report["fields"].items()))
        await ctx.message.add_reaction("✅")

    @bot.command(name="lookup")
    async def lookup(ctx, username: str = ""):
        role_names = [role.name for role in getattr(ctx.author, "roles", [])]
        if not core.has_support_role(role_names):
            await ctx.send(core.MSG_NO_PERMISSION)
            return
        if not lookup_limiter.allow(ctx.author.id):
            await ctx.send(core.rate_limit_message(lookup_limiter.retry_after(ctx.author.id)))
            return
        embed_data = core.lookup_embed(username, fetch_player)
        if embed_data is None:
            await ctx.send(core.MSG_NOT_FOUND)
            return
        embed = discord.Embed(title=embed_data["title"])
        for name, value in embed_data["fields"].items():
            embed.add_field(name=name, value=str(value))
        await ctx.send(embed=embed)

    @bot.event
    async def on_command_error(ctx, error):
        # Unknown command: silent ignore (no channel noise).
        if isinstance(error, commands.CommandNotFound):
            return
        raise error

    bot.run(os.environ["BOT_TOKEN"])


if __name__ == "__main__":
    main()
