import discord
from discord.ext import commands
from discord import app_commands
import os
import time
import secrets
import string
from dotenv import load_dotenv
from aiohttp import web
import asyncio
import json

# Try importing both database drivers
try:
    import asyncpg
    HAS_ASYNCPG = True
except ImportError:
    HAS_ASYNCPG = False

import sqlite3
from contextlib import contextmanager

load_dotenv()

# ========== DATABASE CONFIGURATION ==========
DATABASE_URL = os.getenv('DATABASE_URL')
USE_POSTGRES = DATABASE_URL and HAS_ASYNCPG
DATA_DIR = os.getenv('DATA_DIR', '/app/data')
os.makedirs(DATA_DIR, exist_ok=True)
DB_NAME = os.path.join(DATA_DIR, 'licenses.db')

db_pool = None  # For PostgreSQL

if USE_POSTGRES:
    print("[Database] Using PostgreSQL")
else:
    print("[Database] Using SQLite")

# ========== SQLITE HELPERS ==========
@contextmanager
def get_db_connection():
    """SQLite connection with WAL mode"""
    conn = sqlite3.connect(DB_NAME, timeout=30.0)
    conn.execute('PRAGMA journal_mode=WAL')
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()

def init_sqlite_db():
    """Initialize SQLite database"""
    with get_db_connection() as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS licenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            discord_id TEXT NOT NULL,
            discord_name TEXT NOT NULL,
            key TEXT UNIQUE NOT NULL,
            hwid TEXT DEFAULT 'UNBOUND',
            roblox_id TEXT DEFAULT 'Unknown',
            status TEXT DEFAULT 'active',
            created_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            last_hwid_reset INTEGER DEFAULT 0
        )''')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_discord_id ON licenses(discord_id)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_key ON licenses(key)')
    print("[SQLite] Database initialized")

# ========== POSTGRESQL HELPERS ==========
async def init_postgres_db():
    """Initialize PostgreSQL database"""
    global db_pool
    try:
        db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=10)
        async with db_pool.acquire() as conn:
            await conn.execute('''CREATE TABLE IF NOT EXISTS licenses (
                id SERIAL PRIMARY KEY,
                discord_id TEXT NOT NULL,
                discord_name TEXT NOT NULL,
                key TEXT UNIQUE NOT NULL,
                hwid TEXT DEFAULT 'UNBOUND',
                roblox_id TEXT DEFAULT 'Unknown',
                status TEXT DEFAULT 'active',
                created_at BIGINT NOT NULL,
                expires_at BIGINT NOT NULL,
                last_hwid_reset BIGINT DEFAULT 0
            )''')
            await conn.execute('CREATE INDEX IF NOT EXISTS idx_discord_id ON licenses(discord_id)')
            await conn.execute('CREATE INDEX IF NOT EXISTS idx_key ON licenses(key)')
        print("[PostgreSQL] Database initialized")
    except Exception as e:
        print(f"[PostgreSQL] Initialization failed: {e}")
        raise

# ========== UNIFIED DATABASE INTERFACE ==========
async def db_execute(query, *args):
    """Execute query on either PostgreSQL or SQLite"""
    if USE_POSTGRES:
        async with db_pool.acquire() as conn:
            # Convert SQLite placeholders (?) to PostgreSQL ($1, $2, etc.)
            pg_query = query
            for i in range(len(args), 0, -1):
                pg_query = pg_query.replace('?', f'${i}', 1)
            return await conn.fetch(pg_query, *args)
    else:
        # For SQLite, run in executor to avoid blocking
        loop = asyncio.get_event_loop()
        def sync_query():
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, args)
                return cursor.fetchall()
        return await loop.run_in_executor(None, sync_query)

async def db_execute_one(query, *args):
    """Execute query and return single row"""
    result = await db_execute(query, *args)
    return result[0] if result else None

# ========== BOT SETUP ==========
intents = discord.Intents.default()
intents.message_content = True
intents.members = True

bot = commands.Bot(command_prefix="/", intents=intents)

OWNER_IDS = [int(x.strip()) for x in os.getenv('OWNER_IDS', '').split(',') if x.strip()]

def is_owner(interaction: discord.Interaction) -> bool:
    return interaction.user.id in OWNER_IDS

def generate_key() -> str:
    """Generate PXHB-XXXX-XXXX-XXXX format key"""
    parts = [''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(4)) for _ in range(3)]
    return f"PXHB-{'-'.join(parts)}"

# ========== COMMANDS ==========
@bot.tree.command(name="genkey", description="Generate a license key (Owner Only)")
async def genkey(interaction: discord.Interaction, user: discord.Member, days: int):
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners**.", ephemeral=True)
        return
    
    await interaction.response.defer(ephemeral=True)
    
    try:
        key = generate_key()
        created_at = int(time.time())
        expires_at = created_at + (days * 86400)
        
        if USE_POSTGRES:
            async with db_pool.acquire() as conn:
                await conn.execute(
                    '''INSERT INTO licenses (discord_id, discord_name, key, created_at, expires_at)
                       VALUES ($1, $2, $3, $4, $5)''',
                    str(user.id), str(user), key, created_at, expires_at
                )
        else:
            with get_db_connection() as conn:
                conn.execute(
                    '''INSERT INTO licenses (discord_id, discord_name, key, created_at, expires_at)
                       VALUES (?, ?, ?, ?, ?)''',
                    (str(user.id), str(user), key, created_at, expires_at)
                )
        
        embed = discord.Embed(title="✅ License Key Generated", color=0x00FF00)
        embed.add_field(name="User", value=user.mention, inline=False)
        embed.add_field(name="Key", value=f"`{key}`", inline=False)
        embed.add_field(name="Duration", value=f"{days} days", inline=False)
        await interaction.followup.send(embed=embed, ephemeral=True)
        
    except Exception as e:
        await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)

@bot.tree.command(name="stats", description="View license statistics (Owner Only)")
async def stats(interaction: discord.Interaction):
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners**.", ephemeral=True)
        return
    
    await interaction.response.defer(ephemeral=True)
    
    try:
        current_time = int(time.time())
        
        if USE_POSTGRES:
            async with db_pool.acquire() as conn:
                total = await conn.fetchval('SELECT COUNT(*) FROM licenses')
                active = await conn.fetchval('SELECT COUNT(*) FROM licenses WHERE status = $1 AND expires_at > $2', 'active', current_time)
                revoked = await conn.fetchval('SELECT COUNT(*) FROM licenses WHERE status = $1', 'revoked')
                expired = await conn.fetchval('SELECT COUNT(*) FROM licenses WHERE expires_at <= $1 AND status != $2', current_time, 'revoked')
        else:
            with get_db_connection() as conn:
                total = conn.execute('SELECT COUNT(*) FROM licenses').fetchone()[0]
                active = conn.execute('SELECT COUNT(*) FROM licenses WHERE status = ? AND expires_at > ?', ('active', current_time)).fetchone()[0]
                revoked = conn.execute('SELECT COUNT(*) FROM licenses WHERE status = ?', ('revoked',)).fetchone()[0]
                expired = conn.execute('SELECT COUNT(*) FROM licenses WHERE expires_at <= ? AND status != ?', (current_time, 'revoked')).fetchone()[0]
        
        embed = discord.Embed(title="📊 License Statistics", color=0x5865F2)
        embed.add_field(name="Total Keys", value=f"`{total}`", inline=True)
        embed.add_field(name="Active", value=f"✅ `{active}`", inline=True)
        embed.add_field(name="Expired", value=f"⏳ `{expired}`", inline=True)
        embed.add_field(name="Revoked", value=f"❌ `{revoked}`", inline=True)
        embed.add_field(name="Database", value=f"{'🐘 PostgreSQL' if USE_POSTGRES else '💾 SQLite'}", inline=True)
        await interaction.followup.send(embed=embed, ephemeral=True)
        
    except Exception as e:
        await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)

# ========== VERIFY ENDPOINT ==========
async def handle_verify(request):
    """Verify license key via HTTP endpoint"""
    try:
        data = await request.json()
        key = data.get('key')
        hwid = data.get('hwid')
        roblox_id = str(data.get('roblox_id', 'Unknown'))
        
        if not key or not hwid:
            return web.json_response({'success': False, 'error': 'Missing key or HWID'}, status=400)
        
        current_time = int(time.time())
        
        if USE_POSTGRES:
            async with db_pool.acquire() as conn:
                row = await conn.fetchrow('SELECT * FROM licenses WHERE key = $1', key)
        else:
            loop = asyncio.get_event_loop()
            def get_license():
                with get_db_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute('SELECT * FROM licenses WHERE key = ?', (key,))
                    return cursor.fetchone()
            row = await loop.run_in_executor(None, get_license)
        
        if not row:
            return web.json_response({'success': False, 'error': 'Invalid Key'}, status=403)
        
        row_dict = dict(row) if USE_POSTGRES else dict(row)
        
        # Check expiration
        if row_dict['expires_at'] <= current_time:
            return web.json_response({'success': False, 'error': 'Key Expired'}, status=403)
        
        # Check revoked
        if row_dict['status'] == 'revoked':
            return web.json_response({'success': False, 'error': 'Key Revoked'}, status=403)
        
        # First use or HWID check
        db_hwid = row_dict['hwid']
        if db_hwid == 'UNBOUND':
            # Bind HWID and Roblox ID
            if USE_POSTGRES:
                async with db_pool.acquire() as conn:
                    await conn.execute('UPDATE licenses SET hwid = $1, roblox_id = $2 WHERE key = $3', hwid, roblox_id, key)
            else:
                loop = asyncio.get_event_loop()
                def bind_hwid():
                    with get_db_connection() as conn:
                        conn.execute('UPDATE licenses SET hwid = ?, roblox_id = ? WHERE key = ?', (hwid, roblox_id, key))
                await loop.run_in_executor(None, bind_hwid)
        elif db_hwid != hwid:
            return web.json_response({'success': False, 'error': 'HWID Mismatch'}, status=403)
        
        return web.json_response({'success': True, 'message': 'Authenticated'}, status=200)
        
    except Exception as e:
        print(f'[Verify Error] {e}')
        return web.json_response({'success': False, 'error': 'Internal Error'}, status=500)


class ExternalPanelView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)
        download_btn = discord.ui.Button(
            label="Download External",
            emoji="📥",
            style=discord.ButtonStyle.link,
            url="https://github.com/Americanbreathing/Keypsal/releases/latest/download/PXHB_External_v1.0_RELEASE.zip"
        )
        self.add_item(download_btn)

    @discord.ui.button(label="HWID Reset", emoji="🖥️", style=discord.ButtonStyle.primary, custom_id="ext_hwid_reset")
    async def hwid_reset(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer(ephemeral=True)
        try:
            user_id = str(interaction.user.id)
            current_time = int(time.time())
            cooldown_days = 7
            cooldown_seconds = cooldown_days * 24 * 60 * 60
            
            query = '''SELECT id, key, hwid, last_hwid_reset, expires_at 
                      FROM licenses WHERE discord_id = ? AND status != ? AND expires_at > ?
                      ORDER BY created_at DESC LIMIT 1'''
            row = await db_execute_one(query, user_id, 'revoked', current_time)
            
            if not row:
                embed = discord.Embed(title="❌ No Active License", description="You need an active license to reset HWID.", color=0xFF5555)
                await interaction.followup.send(embed=embed, ephemeral=True)
                return
            
            row_dict = dict(row) if USE_POSTGRES else dict(row)
            license_id, last_reset = row_dict['id'], row_dict.get('last_hwid_reset', 0)
            
            if last_reset and (current_time - last_reset) < cooldown_seconds:
                remaining = cooldown_seconds - (current_time - last_reset)
                days, hours = remaining // 86400, (remaining % 86400) // 3600
                embed = discord.Embed(title="⏰ HWID Reset Cooldown", description=f"You can reset your HWID in **{days}d {hours}h**.", color=0xFFAA00)
                await interaction.followup.send(embed=embed, ephemeral=True)
                return
            
            update_query = '''UPDATE licenses SET hwid = ?, last_hwid_reset = ? WHERE id = ?'''
            await db_execute(update_query, 'UNBOUND', current_time, license_id)
            
            embed = discord.Embed(title="✅ HWID Reset Successful", description="Your HWID has been reset! Launch PXHB_External.exe on your new PC.", color=0x55FF55)
            await interaction.followup.send(embed=embed, ephemeral=True)
        except Exception as e:
            await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)

    @discord.ui.button(label="Setup Guide", emoji="📖", style=discord.ButtonStyle.secondary, custom_id="ext_guide")
    async def setup_guide(self, interaction: discord.Interaction, button: discord.ui.Button):
        embed = discord.Embed(title="📖 External Setup Guide", color=0x5865F2)
        embed.description = (
            "Follow these steps to get PXHB External running:\n\n"
            "1. **Download External**: Click 'Download External' button above\n"
            "2. **Extract ZIP**: Extract all files to a folder\n"
            "3. **Launch Roblox**: Open Roblox and join any supported game\n"
            "4. **Run External**: Open PXHB_External.exe and enter your license key\n"
            "5. **Enjoy**: The overlay will appear once authenticated!"
        )
        embed.add_field(name="⚠️ Important", value="Keep the folder structure intact! Don't move files.", inline=False)
        await interaction.response.send_message(embed=embed, ephemeral=True)

@bot.tree.command(name="extpanel", description="Send the External Support panel (Owner Only)")
async def extpanel(interaction: discord.Interaction):
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners**.", ephemeral=True)
        return
    
    embed = discord.Embed(
        title="📥 PXHB External Download",
        description="Download and setup PXHB External cheat.\n\nClick the button below to download the latest version.",
        color=0x5865F2
    )
    embed.add_field(name="What's Included", value="✅ Self-contained exe (no .NET needed)\n✅ Pattern scanner (PXHB.dll)\n✅ Offset files\n✅ Setup guide", inline=False)
    embed.set_footer(text="Need help? Click 'Setup Guide' after downloading.")
    
    view = ExternalPanelView()
    await interaction.response.send_message(embed=embed, view=view)

# ========== BOT EVENTS ==========
@bot.event
async def on_ready():
    if USE_POSTGRES:
        await init_postgres_db()
    else:
        init_sqlite_db()
    
    await bot.tree.sync()
    print(f'Logged in as {bot.user.name} (ID: {bot.user.id})')
    print(f'Synced {len(await bot.tree.fetch_commands())} commands')
    
    # Start webhook server
    app = web.Application()
    app.router.add_post('/verify', handle_verify)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8080)
    await site.start()
    print('Webhook server running on port 8080')

# ========== RUN BOT ==========
if __name__ == '__main__':
    token = os.getenv('DISCORD_TOKEN')
    if not token:
        print("Error: DISCORD_TOKEN not found in .env")
    else:
        bot.run(token)
