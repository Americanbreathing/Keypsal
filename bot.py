import discord
from discord import app_commands
from discord.ext import commands, tasks
import os
import base64
import time
import json
import sqlite3
from datetime import datetime
from dotenv import load_dotenv
from aiohttp import web
import asyncio

# Load environment variables
load_dotenv()
TOKEN = os.getenv('DISCORD_TOKEN')

# CONFIGURATION
SECRET_KEY = "PXHB_SECRET_KEY_8829" # MUST MATCH LUA SCRIPT
WEBHOOK_PORT = int(os.getenv('PORT', 8080))  # Dynamic port for Railway/Cloud
DB_NAME = 'licenses.db'
CUSTOMER_ROLE_ID = 1456538123629494335 # Customer Role ID

# ==============================================================================
# DATABASE HELPERS
# ==============================================================================
def get_db_connection():
    """Returns a thread-safe connection with WAL mode enabled."""
    conn = sqlite3.connect(DB_NAME, timeout=15)
    conn.execute('PRAGMA journal_mode=WAL;')
    conn.execute('PRAGMA synchronous=NORMAL;')
    return conn

def init_db():
    with get_db_connection() as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS licenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            discord_id TEXT NOT NULL,
            discord_name TEXT NOT NULL,
            key TEXT UNIQUE NOT NULL,
            hwid TEXT,
            status TEXT DEFAULT 'pending',
            created_at INTEGER NOT NULL,
            activated_at INTEGER,
            expires_at INTEGER NOT NULL
        )''')

init_db()

# ==============================================================================
# ROLE HELPERS
# ==============================================================================
async def check_and_update_role(guild, user_id):
    """Checks if a user has any valid licenses and updates their role accordingly."""
    try:
        current_time = int(time.time())
        has_active = False
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''SELECT COUNT(*) FROM licenses 
                            WHERE discord_id = ? AND status != 'revoked' AND expires_at > ?''', 
                         (str(user_id), current_time))
            count = cursor.fetchone()[0]
            has_active = (count > 0)
        
        member = guild.get_member(int(user_id)) or await guild.fetch_member(int(user_id))
        if not member:
            return
            
        role = guild.get_role(CUSTOMER_ROLE_ID)
        if not role:
            print(f"[Role Error] Role ID {CUSTOMER_ROLE_ID} not found in guild.")
            return

        if has_active:
            if role not in member.roles:
                await member.add_roles(role)
                print(f"[Role] Assigned role to {member.name}")
        else:
            if role in member.roles:
                await member.remove_roles(role)
                print(f"[Role] Removed role from {member.name} (No active licenses)")
                
    except Exception as e:
        print(f"[Role Error] Failed to update role for {user_id}: {e}")

# ==============================================================================
# CRYPTO LOGIC (Custom XOR Cipher)
# ==============================================================================
def encrypt_string(text, key):
    result = []
    key_len = len(key)
    for i, char in enumerate(text):
        key_char = key[i % key_len]
        encrypted_char = chr(ord(char) ^ ord(key_char))
        result.append(encrypted_char)
    return "".join(result)

import secrets
import string

def generate_license(hwid, days):
    if days >= 999:
        expiry_timestamp = 9999999999
    else:
        expiry_timestamp = int(time.time()) + (days * 86400)
    
    # Add random salt to ensure uniqueness (fixes UNIQUE constraint error)
    salt = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(6))
    payload = f"{hwid}|{expiry_timestamp}|{salt}"
    
    encrypted_payload = encrypt_string(payload, SECRET_KEY)
    b64_bytes = base64.b64encode(encrypted_payload.encode('utf-8'))
    license_key = b64_bytes.decode('utf-8')
    
    return license_key, expiry_timestamp

# ==============================================================================
# WEBHOOK SERVER (Receives HWID from Lua)
# ==============================================================================
async def handle_activation(request):
    try:
        data = await request.json()
        key = data.get('key')
        hwid = data.get('hwid')
        
        if not key or not hwid:
            return web.json_response({'success': False, 'error': 'Missing key or hwid'}, status=400)
        
        # Update database
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''UPDATE licenses 
                         SET hwid = ?, status = 'active', activated_at = ? 
                         WHERE key = ? AND status = 'pending' ''',
                      (hwid, int(time.time()), key))
            
            if cursor.rowcount == 0:
                return web.json_response({'success': False, 'error': 'Key not found or already activated'}, status=404)
        
        return web.json_response({'success': True, 'message': 'Key activated successfully'})
    
    except Exception as e:
        return web.json_response({'success': False, 'error': str(e)}, status=500)

async def start_webhook_server():
    app = web.Application()
    app.router.add_post('/activate', handle_activation)
    runner = web.AppRunner(app)
    await runner.setup()
    # Listen on all interfaces
    site = web.TCPSite(runner, '0.0.0.0', WEBHOOK_PORT)
    await site.start()
    print(f'Webhook server running on port {WEBHOOK_PORT}')

# ==============================================================================
# BOT SETUP
# ==============================================================================
# IMPORTANT: Enable Members intent for role management
intents = discord.Intents.default()
intents.members = True 
bot = commands.Bot(command_prefix="!", intents=intents)

@bot.event
async def on_ready():
    print(f'Logged in as {bot.user} (ID: {bot.user.id})')
    try:
        synced = await bot.tree.sync()
        print(f'Synced {len(synced)} commands')
    except Exception as e:
        print(f'Sync error: {e}')
    
    # Start background tasks
    check_expirations.start()
    asyncio.create_task(start_webhook_server())

# Periodically check for expired licenses and remove roles
@tasks.loop(minutes=30)
async def check_expirations():
    print("[Task] Checking for license expirations...")
    try:
        # Get all unique discord IDs in the database
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT DISTINCT discord_id FROM licenses')
            users = cursor.fetchall()
            
        for guild in bot.guilds:
            for row in users:
                user_id = row[0]
                await check_and_update_role(guild, user_id)
    except Exception as e:
        print(f"[Task Error] Error in check_expirations: {e}")

# ==============================================================================
# SLASH COMMANDS
# ==============================================================================

@bot.tree.command(name="genkey", description="Generate a license key for a user")
@app_commands.describe(user="The Discord user to generate a key for", days="Duration in days (999 for lifetime)")
@app_commands.checks.has_permissions(administrator=True)
async def genkey(interaction: discord.Interaction, user: discord.User, days: int = 30):
    await interaction.response.defer(ephemeral=True)
    
    try:
        # Generate UNBOUND key
        key, expiry = generate_license("UNBOUND", days)
        
        # Store in database
        with get_db_connection() as conn:
            conn.execute('''INSERT INTO licenses (discord_id, discord_name, key, created_at, expires_at)
                         VALUES (?, ?, ?, ?, ?)''',
                      (str(user.id), str(user), key, int(time.time()), expiry))
        
        # Add Customer Role immediately
        await check_and_update_role(interaction.guild, user.id)
        
        # Format response
        if days >= 999:
            expiry_str = "Lifetime"
        else:
            expiry_str = f"<t:{expiry}:R>"
            
        embed = discord.Embed(title="License Generated", color=0x00ff00)
        embed.add_field(name="User", value=user.mention, inline=False)
        embed.add_field(name="Duration", value=f"{days} Days ({expiry_str})", inline=True)
        embed.add_field(name="Status", value="⏳ Pending Activation", inline=True)
        embed.add_field(name="License Key", value=f"```{key}```", inline=False)
        embed.set_footer(text="User has been assigned the Customer role.")
        
        await interaction.followup.send(embed=embed, ephemeral=True)
        
        # Optionally DM the user
        try:
            dm_embed = discord.Embed(title="Your PXHB License Key", color=0x00ff00)
            dm_embed.add_field(name="Key", value=f"```{key}```", inline=False)
            dm_embed.add_field(name="Expires", value=expiry_str, inline=True)
            dm_embed.set_footer(text="Paste this key into the script to activate.")
            await user.send(embed=dm_embed)
        except:
            pass  # User has DMs disabled
        
    except Exception as e:
        await interaction.followup.send(f"Error: {str(e)}", ephemeral=True)

@bot.tree.command(name="userinfo", description="View a user's license information")
@app_commands.describe(user="The Discord user to check")
@app_commands.checks.has_permissions(administrator=True)
async def userinfo(interaction: discord.Interaction, user: discord.User):
    await interaction.response.defer(ephemeral=True)
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM licenses WHERE discord_id = ? ORDER BY created_at DESC', (str(user.id),))
            licenses = cursor.fetchall()
        
        if not licenses:
            await interaction.followup.send(f"{user.mention} has no licenses.", ephemeral=True)
            return
        
        embed = discord.Embed(title=f"Licenses for {user.name}", color=0x5865F2)
        
        for lic in licenses:
            status_emoji = {"pending": "⏳", "active": "✅", "revoked": "❌"}.get(lic[5], "❓")
            hwid_display = lic[4][:16] + "..." if lic[4] else "Not activated"
            expires = datetime.fromtimestamp(lic[8]).strftime("%Y-%m-%d") if lic[8] < 9999999999 else "Lifetime"
            
            embed.add_field(
                name=f"{status_emoji} {lic[5].upper()}",
                value=f"**Key:** `{lic[3][:20]}...`\n**HWID:** `{hwid_display}`\n**Expires:** {expires}",
                inline=False
            )
        
        await interaction.followup.send(embed=embed, ephemeral=True)
        
    except Exception as e:
        await interaction.followup.send(f"Error: {str(e)}", ephemeral=True)

@bot.tree.command(name="revoke", description="Revoke a user's license")
@app_commands.describe(user="The Discord user whose license to revoke")
@app_commands.checks.has_permissions(administrator=True)
async def revoke(interaction: discord.Interaction, user: discord.User):
    await interaction.response.defer(ephemeral=True)
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("UPDATE licenses SET status = 'revoked' WHERE discord_id = ? AND status != 'revoked'", (str(user.id),))
            count = cursor.rowcount
            
        # Re-check and potentially remove role
        await check_and_update_role(interaction.guild, user.id)
        
        if count > 0:
            await interaction.followup.send(f"✅ Revoked {count} license(s) for {user.mention}. Role updated.", ephemeral=True)
        else:
            await interaction.followup.send(f"{user.mention} has no active licenses to revoke.", ephemeral=True)
        
    except Exception as e:
        await interaction.followup.send(f"Error: {str(e)}", ephemeral=True)

@bot.tree.command(name="stats", description="View license statistics")
@app_commands.checks.has_permissions(administrator=True)
async def stats(interaction: discord.Interaction):
    await interaction.response.defer(ephemeral=True)
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) FROM licenses")
            total = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM licenses WHERE status = 'active'")
            active = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM licenses WHERE status = 'pending'")
            pending = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM licenses WHERE status = 'revoked'")
            revoked = cursor.fetchone()[0]
        
        embed = discord.Embed(title="License Statistics", color=0x5865F2)
        embed.add_field(name="Total Keys", value=str(total), inline=True)
        embed.add_field(name="✅ Active", value=str(active), inline=True)
        embed.add_field(name="⏳ Pending", value=str(pending), inline=True)
        embed.add_field(name="❌ Revoked", value=str(revoked), inline=True)
        
        await interaction.followup.send(embed=embed, ephemeral=True)
        
    except Exception as e:
        await interaction.followup.send(f"Error: {str(e)}", ephemeral=True)

@bot.tree.command(name="help", description="Show bot commands")
async def help_command(interaction: discord.Interaction):
    embed = discord.Embed(title="PXHB Bot Commands", color=0x5865F2)
    embed.add_field(name="/genkey @user <days>", value="Generate a license (Auto-assigns Customer role)", inline=False)
    embed.add_field(name="/userinfo @user", value="View user's licenses", inline=False)
    embed.add_field(name="/revoke @user", value="Revoke licenses (Auto-takes Customer role)", inline=False)
    embed.add_field(name="/stats", value="View license statistics", inline=False)
    await interaction.response.send_message(embed=embed, ephemeral=True)

# Run Bot
if __name__ == "__main__":
    if TOKEN:
        bot.run(TOKEN)
    else:
        print("Error: DISCORD_TOKEN not found in .env")
