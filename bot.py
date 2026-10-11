import os, platform, shutil, time, asyncio
from pathlib import Path
import discord
from discord.ext import commands
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env")
TOKEN = os.getenv("DISCORD_TOKEN", "").strip()
OWNER_IDS = {int(x) for x in os.getenv("OWNER_IDS", "").split(",") if x.strip().isdigit()}
PREFIX = os.getenv("COMMAND_PREFIX", "!")
STARTED = time.time()

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix=PREFIX, intents=intents, help_command=None)

def owner_only():
    async def check(ctx):
        if not OWNER_IDS or ctx.author.id not in OWNER_IDS:
            raise commands.CheckFailure("Only configured bot owners can use this command.")
        return True
    return commands.check(check)

@bot.event
async def on_ready():
    print(f"Connected as {bot.user} ({bot.user.id})")
    try:
        synced = await bot.tree.sync()
        print(f"Synced {len(synced)} slash commands")
    except Exception as e:
        print(f"Slash sync error: {e}")

@bot.command()
async def ping(ctx):
    await ctx.reply(f"Pong! {round(bot.latency*1000)} ms", mention_author=False)

@bot.command(name="help")
async def help_command(ctx):
    await ctx.reply(
        f"**VPS Deploy Bot**\n`{PREFIX}ping` — latency\n"
        f"`{PREFIX}status` — host status\n`{PREFIX}help` — help\n"
        f"`{PREFIX}diagnose disk|uptime|python` — owner diagnostics",
        mention_author=False
    )

@bot.command()
async def status(ctx):
    total, used, free = shutil.disk_usage(ROOT)
    await ctx.reply(
        f"**Host Status**\nPlatform: `{platform.platform()}`\n"
        f"Disk used: `{used/1024**3:.2f}/{total/1024**3:.2f} GiB`\n"
        f"Free: `{free/1024**3:.2f} GiB`\nUptime: `{int(time.time()-STARTED)}s`",
        mention_author=False
    )

@bot.command()
@owner_only()
async def diagnose(ctx, kind: str = "disk"):
    commands_map = {
        "disk": ["df", "-h"],
        "uptime": ["uptime"],
        "python": [os.sys.executable, "--version"],
    }
    if kind not in commands_map:
        await ctx.reply("Allowed: `disk`, `uptime`, `python`", mention_author=False)
        return
    try:
        p = await asyncio.create_subprocess_exec(
            *commands_map[kind], stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )
        out, _ = await asyncio.wait_for(p.communicate(), timeout=10)
        await ctx.reply("```text\n" + out.decode(errors="replace")[:1700] + "\n```", mention_author=False)
    except Exception as e:
        await ctx.reply(f"Diagnostic failed: `{e}`", mention_author=False)

@bot.tree.command(name="ping", description="Check bot latency")
async def slash_ping(interaction: discord.Interaction):
    await interaction.response.send_message(f"Pong! {round(bot.latency*1000)} ms", ephemeral=True)

@bot.tree.command(name="status", description="Show host disk status")
async def slash_status(interaction: discord.Interaction):
    total, used, free = shutil.disk_usage(ROOT)
    await interaction.response.send_message(
        f"Platform: `{platform.system()} {platform.release()}`\n"
        f"Disk: `{used/1024**3:.2f}/{total/1024**3:.2f} GiB used`",
        ephemeral=True
    )

if __name__ == "__main__":
    if not TOKEN:
        raise SystemExit("DISCORD_TOKEN missing. Choose menu option 2 first.")
    bot.run(TOKEN, log_handler=None)
