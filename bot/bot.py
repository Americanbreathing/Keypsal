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
ALERT_CHANNEL_ID = int(os.getenv('ALERT_CHANNEL_ID', '1456538170869944414')) # Admin Alert Channel

# CONFIGURATION
SECRET_KEY = "PXHB_SECRET_KEY_8829" # MUST MATCH LUA SCRIPT
WEBHOOK_PORT = int(os.getenv('PORT', 8080))  # Dynamic port for Railway/Cloud

# Persistence Logic: Check for Railway Volume mount path
# Default to current directory if not found
DATA_DIR = os.getenv('DATA_DIR', '/app/data' if os.path.exists('/app/data') else '.')
DB_NAME = os.path.join(DATA_DIR, 'licenses.db')

# Ensure directory exists
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

print(f"[System] Database path: {DB_NAME}")
CUSTOMER_ROLE_ID = 1456538123629494335 # Customer Role ID
OWNER_ROLE_ID = 1456538170869944414 # Owner Role ID

# VERSION INFO (Update these when pushing new script)
SCRIPT_VERSION = "2.2.0"
LAST_UPDATE = "February 2, 2026 1:30 AM EST"
CHANGELOG = [
    "🔒 NEW: Strict HWID + Roblox ID verification",
    "🔒 NEW: Anti key-sharing detection",
    "🔒 NEW: Admin security alerts",
    "Fixed AC Bypasser timing (3s init delay)",
    "Console cleaner active"
]

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
            expires_at INTEGER NOT NULL,
            last_hwid_reset INTEGER DEFAULT 0
        )''')
        conn.execute('''CREATE TABLE IF NOT EXISTS sellers (
            discord_id TEXT PRIMARY KEY,
            discord_name TEXT NOT NULL,
            added_at INTEGER NOT NULL
        )''')
        # Schema Migration: Ensure roblox_id exists for multi-account detection
        try:
            conn.execute("ALTER TABLE licenses ADD COLUMN roblox_id TEXT")
        except sqlite3.OperationalError:
            pass # Column already exists
        conn.execute('''CREATE TABLE IF NOT EXISTS configs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            user_name TEXT NOT NULL,
            script_name TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            data TEXT NOT NULL,
            upvotes INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
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
async def send_security_alert(discord_id, key, hwid, old_hwid, rid, old_rid, reason):
    """Sends a security alert to the admin channel."""
    try:
        channel = bot.get_channel(ALERT_CHANNEL_ID)
        if not channel:
            print(f"[Alert Error] Channel {ALERT_CHANNEL_ID} not found")
            return
            
        embed = discord.Embed(title="🚨 SECURITY ALERT: Key Compromised", color=0xFF0000)
        embed.add_field(name="Reason", value=f"**{reason}**", inline=False)
        embed.add_field(name="User ID", value=f"`{discord_id}` (<@{discord_id}>)", inline=True)
        embed.add_field(name="Key", value=f"||{key[:20]}...||", inline=True)
        
        if reason == "HWID Mismatch":
            embed.add_field(name="Original HWID", value=f"`{old_hwid}`", inline=False)
            embed.add_field(name="New HWID Attempt", value=f"`{hwid}`", inline=False)
        elif reason == "Account Mismatch":
            embed.add_field(name="Original Roblox ID", value=f"`{old_rid}`", inline=False)
            embed.add_field(name="New Roblox ID", value=f"`{rid}`", inline=False)
            
        embed.set_footer(text="Access Blocked.")
        await channel.send(embed=embed)
    except Exception as e:
        print(f"[Alert Error] Failed to send alert: {e}")

async def handle_verify(request):
    """Strict key verification: checks HWID, RobloxID, expiration."""
    try:
        data = await request.json()
        key = data.get('key')
        hwid = data.get('hwid')
        roblox_id = str(data.get('roblox_id', 'Unknown'))
        
        if not key or not hwid:
            return web.json_response({'success': False, 'error': 'Missing Parameters'}, status=400)
        
        with get_db_connection() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM licenses WHERE key = ?", (key,))
            row = cursor.fetchone()
            
            if not row:
                return web.json_response({'success': False, 'error': 'Invalid Key'}, status=403)
            
            db_hwid = row['hwid']
            db_status = row['status']
            db_expires = row['expires_at']
            db_rid = row['roblox_id'] if 'roblox_id' in row.keys() else None
            
            # 1. Check Expiration
            if db_expires < int(time.time()) and db_expires < 9999999999:
                 return web.json_response({'success': False, 'error': 'Key Expired'}, status=403)

            # 2. Check Revocation
            if db_status == 'revoked':
                 return web.json_response({'success': False, 'error': 'Key Revoked'}, status=403)

            # 3. Activation Logic (First Use)
            if db_status == 'pending':
                cursor.execute("UPDATE licenses SET hwid = ?, roblox_id = ?, status = 'active', activated_at = ? WHERE key = ?",
                             (hwid, roblox_id, int(time.time()), key))
                return web.json_response({'success': True, 'message': 'Activated'})

            # 4. Strict Validation (Already Active)
            if db_hwid != hwid:
                await send_security_alert(row['discord_id'], key, hwid, db_hwid, roblox_id, db_rid, "HWID Mismatch")
                return web.json_response({'success': False, 'error': 'HWID Mismatch'}, status=403)
            
            if db_rid and db_rid != roblox_id:
                await send_security_alert(row['discord_id'], key, hwid, db_hwid, roblox_id, db_rid, "Account Mismatch")
                return web.json_response({'success': False, 'error': 'Account Mismatch: Key locked to another Roblox account.'}, status=403)

            return web.json_response({'success': True, 'message': 'Valid'})
    
    except Exception as e:
        print(f"[Verify Error] {e}")
        return web.json_response({'success': False, 'error': str(e)}, status=500)

# Legacy endpoint for old clients (just activates pending keys)
async def handle_activation(request):
    try:
        data = await request.json()
        key = data.get('key')
        hwid = data.get('hwid')
        
        if not key or not hwid:
            return web.json_response({'success': False, 'error': 'Missing key or hwid'}, status=400)
        
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
    app.router.add_post('/verify', handle_verify)    # NEW: Strict verification
    app.router.add_post('/activate', handle_activation)  # Legacy support
    runner = web.AppRunner(app)
    await runner.setup()
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
# PERMISSION CHECKS
# ==============================================================================
def is_owner(interaction: discord.Interaction):
    """Checks if the user has the Owner role."""
    role = interaction.guild.get_role(OWNER_ROLE_ID)
    return (role in interaction.user.roles if role else False) or interaction.user.guild_permissions.administrator

async def is_seller(interaction: discord.Interaction):
    """Checks if the user is a registered seller or an admin/owner."""
    if is_owner(interaction):
        return True
        
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT 1 FROM sellers WHERE discord_id = ?", (str(interaction.user.id),))
        return cursor.fetchone() is not None

# ==============================================================================
# SELLERS MANAGEMENT (OWNER ONLY)
# ==============================================================================

@bot.tree.command(name="addseller", description="Add a new authorized seller (Owner Only)")
@app_commands.describe(user="The Discord user to authorize as a seller")
async def addseller(interaction: discord.Interaction, user: discord.Member):
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners**.", ephemeral=True)
        return
        
    try:
        with get_db_connection() as conn:
            conn.execute("INSERT OR REPLACE INTO sellers (discord_id, discord_name, added_at) VALUES (?, ?, ?)",
                      (str(user.id), str(user), int(time.time())))
        await interaction.response.send_message(f"✅ {user.mention} is now an authorized **Seller**.", ephemeral=True)
    except Exception as e:
        await interaction.response.send_message(f"Error: {e}", ephemeral=True)

@bot.tree.command(name="removeseller", description="Remove an authorized seller (Owner Only)")
@app_commands.describe(user="The Discord user to remove from sellers")
async def removeseller(interaction: discord.Interaction, user: discord.User):
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners**.", ephemeral=True)
        return
        
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM sellers WHERE discord_id = ?", (str(user.id),))
            count = cursor.rowcount
            
        if count > 0:
            await interaction.response.send_message(f"✅ Removed {user.mention} from authorized sellers.", ephemeral=True)
        else:
            await interaction.response.send_message(f"❌ {user.mention} was not a registered seller.", ephemeral=True)
    except Exception as e:
        await interaction.response.send_message(f"Error: {e}", ephemeral=True)

# ==============================================================================
# SLASH COMMANDS
# ==============================================================================

@bot.tree.command(name="genkey", description="Generate a license key for a user")
@app_commands.describe(user="The Discord user to generate a key for", days="Duration in days (999 for lifetime)")
async def genkey(interaction: discord.Interaction, user: discord.User, days: int = 30):
    if not await is_seller(interaction):
        await interaction.response.send_message("❌ Access Denied: You are not an authorized **Seller**.", ephemeral=True)
        return
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
async def userinfo(interaction: discord.Interaction, user: discord.User):
    if not await is_seller(interaction):
        await interaction.response.send_message("❌ Access Denied.", ephemeral=True)
        return
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
async def revoke(interaction: discord.Interaction, user: discord.User):
    if not await is_seller(interaction):
        await interaction.response.send_message("❌ Access Denied.", ephemeral=True)
        return
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
async def stats(interaction: discord.Interaction):
    if not await is_seller(interaction):
        await interaction.response.send_message("❌ Access Denied.", ephemeral=True)
        return
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
    embed.add_field(name="/genkey @user <days>", value="Generate a license (Sellers Only)", inline=False)
    embed.add_field(name="/userinfo @user", value="View user's licenses", inline=False)
    embed.add_field(name="/revoke @user", value="Revoke licenses", inline=False)
    embed.add_field(name="/stats", value="View license statistics", inline=False)
    
    if is_owner(interaction):
        embed.add_field(name="--- OWNER ONLY ---", value="\u200b", inline=False)
        embed.add_field(name="/addseller @user", value="Authorize a user to sell keys", inline=False)
        embed.add_field(name="/removeseller @user", value="Revoke seller permissions", inline=False)
        embed.add_field(name="/reassignall [days] [revoke_old]", value="Generate new keys for ALL customers", inline=False)
        embed.add_field(name="/backup", value="Download database backup", inline=False)
        
    await interaction.response.send_message(embed=embed, ephemeral=True)

@bot.tree.command(name="backup", description="Download a backup of the license database (Owner Only)")
async def backup(interaction: discord.Interaction):
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners**.", ephemeral=True)
        return
    
    try:
        await interaction.response.defer(ephemeral=True)
        
        # Check if database file exists
        if not os.path.exists(DB_NAME):
            await interaction.followup.send("❌ Database file not found!", ephemeral=True)
            return
        
        # Send the database file as an attachment
        file = discord.File(DB_NAME, filename=f"licenses_backup_{int(time.time())}.db")
        await interaction.followup.send("✅ **Database Backup**\nHere's your backup file:", file=file, ephemeral=True)
        
    except Exception as e:
        await interaction.followup.send(f"❌ Backup failed: {str(e)}", ephemeral=True)

@bot.tree.command(name="reassignall", description="Generate new keys for all members with Customer role (Owner Only)")
@app_commands.describe(
    days="Duration for new keys (default 30, use 999 for lifetime)",
    revoke_old="Revoke old keys before generating new ones (default True)"
)
async def reassignall(interaction: discord.Interaction, days: int = 30, revoke_old: bool = True):
    # STRICT OWNER CHECK - Sellers cannot use this
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners only**. Sellers cannot use this.", ephemeral=True)
        return
    
    await interaction.response.defer(ephemeral=True)
    
    try:
        guild = interaction.guild
        role = guild.get_role(CUSTOMER_ROLE_ID)
        
        if not role:
            await interaction.followup.send(f"❌ Customer role (ID: {CUSTOMER_ROLE_ID}) not found!", ephemeral=True)
            return
        
        # Get all members with the Customer role
        members_with_role = [m for m in guild.members if role in m.roles]
        
        if not members_with_role:
            await interaction.followup.send("❌ No members found with the Customer role.", ephemeral=True)
            return
        
        # Confirm action
        count = len(members_with_role)
        
        # Process each member
        success = 0
        failed = 0
        
        for member in members_with_role:
            try:
                # Optionally revoke old keys
                if revoke_old:
                    with get_db_connection() as conn:
                        conn.execute("UPDATE licenses SET status = 'revoked' WHERE discord_id = ? AND status != 'revoked'", 
                                   (str(member.id),))
                
                # Generate new key
                key, expiry = generate_license("UNBOUND", days)
                
                with get_db_connection() as conn:
                    conn.execute('''INSERT INTO licenses (discord_id, discord_name, key, created_at, expires_at)
                                 VALUES (?, ?, ?, ?, ?)''',
                              (str(member.id), str(member), key, int(time.time()), expiry))
                
                # Try to DM the user their new key
                try:
                    expiry_str = "Lifetime" if days >= 999 else f"<t:{expiry}:R>"
                    dm_embed = discord.Embed(title="🔑 New PXHB License Key", color=0x00ff00)
                    dm_embed.description = "Your license has been reassigned. Here's your new key:"
                    dm_embed.add_field(name="Key", value=f"```{key}```", inline=False)
                    dm_embed.add_field(name="Expires", value=expiry_str, inline=True)
                    dm_embed.set_footer(text="Paste this key into the script to activate.")
                    await member.send(embed=dm_embed)
                except:
                    pass  # DMs disabled
                
                success += 1
                
            except Exception as e:
                print(f"[ReassignAll Error] Failed for {member}: {e}")
                failed += 1
        
        # Report results
        embed = discord.Embed(title="✅ Bulk Key Reassignment Complete", color=0x00ff00)
        embed.add_field(name="Total Members", value=str(count), inline=True)
        embed.add_field(name="Successful", value=str(success), inline=True)
        embed.add_field(name="Failed", value=str(failed), inline=True)
        embed.add_field(name="Key Duration", value=f"{days} days" if days < 999 else "Lifetime", inline=True)
        embed.add_field(name="Old Keys Revoked", value="Yes" if revoke_old else "No", inline=True)
        embed.set_footer(text="New keys have been DMed to users (if DMs enabled).")
        
        await interaction.followup.send(embed=embed, ephemeral=True)
        
    except Exception as e:
        await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)

# ==============================================================================
# INTERACTIVE PANEL (Replaces Web Portal)
# ==============================================================================
class PanelView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)  # Never timeout
    
    @discord.ui.button(label="Login", emoji="🔑", style=discord.ButtonStyle.primary, custom_id="panel_login")
    async def login_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer(ephemeral=True)
        try:
            user_id = str(interaction.user.id)
            current_time = int(time.time())
            
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''SELECT key, status, expires_at, hwid, created_at 
                                FROM licenses WHERE discord_id = ? ORDER BY created_at DESC''', (user_id,))
                licenses = cursor.fetchall()
            
            if not licenses:
                embed = discord.Embed(
                    title="❌ No License Found",
                    description="You don't have any licenses.\nContact an admin to get one!",
                    color=0xFF5555
                )
            else:
                embed = discord.Embed(title="🔑 Your Licenses", color=5814783)
                for lic in licenses:
                    key, status, expires_at, hwid, created_at = lic
                    expires_str = datetime.fromtimestamp(expires_at).strftime('%Y-%m-%d') if expires_at else "N/A"
                    is_expired = expires_at < current_time
                    status_display = "⏰ EXPIRED" if is_expired else f"✅ {status.upper()}"
                    hwid_display = hwid if hwid != "UNBOUND" else "Not activated"
                    
                    embed.add_field(
                        name=f"{status_display}",
                        value=f"**Expires:** {expires_str}\n**HWID:** `{hwid_display[:20]}...`" if len(str(hwid)) > 20 else f"**Expires:** {expires_str}\n**HWID:** `{hwid_display}`",
                        inline=False
                    )
            
            await interaction.followup.send(embed=embed, ephemeral=True)
        except Exception as e:
            await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)
    
    @discord.ui.button(label="Get Script", emoji="📜", style=discord.ButtonStyle.primary, custom_id="panel_getscript")
    async def getscript_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer(ephemeral=True)
        try:
            user_id = str(interaction.user.id)
            current_time = int(time.time())
            
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''SELECT key FROM licenses 
                                WHERE discord_id = ? AND status != 'revoked' AND expires_at > ?
                                ORDER BY created_at DESC LIMIT 1''', (user_id, current_time))
                result = cursor.fetchone()
            
            if not result:
                embed = discord.Embed(
                    title="❌ Access Denied",
                    description="You must have an **Active License** to get the script.\n\n1. Purchase a key\n2. Use `/genkey` (Admin)\n3. Click 'Login' to check status",
                    color=0xFF5555
                )
            else:
                key = result[0]
                # TODO: UPDATE THIS URL TO YOUR RAW LUA SCRIPT URL
                script_url = "https://raw.githubusercontent.com/Americanbreathing/Keypsal/main/PXHV_Scripts/PXHB_FF2_Obfuscated.lua"
                
                script_loader = f'_G.LicenseKey = "{key}"\nloadstring(game:HttpGet("{script_url}"))()'
                
                embed = discord.Embed(
                    title="📜 Your PXHB Script",
                    description="Copy the code below and paste it into your executor.",
                    color=0x55FF55
                )
                embed.add_field(name="Script Loader", value=f"```lua\n{script_loader}\n```", inline=False)
                embed.add_field(name="⚠️ Warning", value="Do NOT share this! The key is linked to your hardware.", inline=False)
            
            await interaction.followup.send(embed=embed, ephemeral=True)
        except Exception as e:
            await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)
    
    @discord.ui.button(label="Stats", emoji="📊", style=discord.ButtonStyle.primary, custom_id="panel_stats")
    async def stats_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer(ephemeral=True)
        try:
            user_id = str(interaction.user.id)
            current_time = int(time.time())
            
            with get_db_connection() as conn:
                cursor = conn.cursor()
                # Get user's license stats
                cursor.execute('SELECT COUNT(*) FROM licenses WHERE discord_id = ?', (user_id,))
                total = cursor.fetchone()[0]
                
                cursor.execute('SELECT COUNT(*) FROM licenses WHERE discord_id = ? AND status = "active" AND expires_at > ?', 
                              (user_id, current_time))
                active = cursor.fetchone()[0]
                
                cursor.execute('SELECT expires_at FROM licenses WHERE discord_id = ? AND expires_at > ? ORDER BY expires_at DESC LIMIT 1', 
                              (user_id, current_time))
                latest_expiry = cursor.fetchone()
            
            if total == 0:
                embed = discord.Embed(
                    title="📊 Your Stats",
                    description="You have no licenses yet!",
                    color=5814783
                )
            else:
                embed = discord.Embed(title="📊 Your License Stats", color=5814783)
                embed.add_field(name="Total Licenses", value=str(total), inline=True)
                embed.add_field(name="Active", value=str(active), inline=True)
                
                if latest_expiry:
                    days_left = (latest_expiry[0] - current_time) // 86400
                    embed.add_field(name="Days Remaining", value=str(max(0, days_left)), inline=True)
            
            await interaction.followup.send(embed=embed, ephemeral=True)
        except Exception as e:
            await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)
    
    @discord.ui.button(label="HWID Reset", emoji="🖥️", style=discord.ButtonStyle.primary, custom_id="panel_hwidreset")
    async def hwidreset_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer(ephemeral=True)
        try:
            user_id = str(interaction.user.id)
            current_time = int(time.time())
            cooldown_days = 7
            cooldown_seconds = cooldown_days * 24 * 60 * 60
            
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''SELECT id, key, hwid, last_hwid_reset, expires_at 
                                FROM licenses WHERE discord_id = ? AND status != 'revoked' AND expires_at > ?
                                ORDER BY created_at DESC LIMIT 1''', (user_id, current_time))
                result = cursor.fetchone()
            
            if not result:
                embed = discord.Embed(
                    title="❌ No Active License",
                    description="You need an active license to reset HWID.",
                    color=0xFF5555
                )
                await interaction.followup.send(embed=embed, ephemeral=True)
                return
            
            license_id, key, hwid, last_reset, expires_at = result
            
            # Check cooldown
            if last_reset and (current_time - last_reset) < cooldown_seconds:
                remaining = cooldown_seconds - (current_time - last_reset)
                days = remaining // 86400
                hours = (remaining % 86400) // 3600
                embed = discord.Embed(
                    title="⏰ HWID Reset Cooldown",
                    description=f"You can reset your HWID in **{days}d {hours}h**.\n\nCooldown: {cooldown_days} days between resets.",
                    color=0xFFAA00
                )
                await interaction.followup.send(embed=embed, ephemeral=True)
                return
            
            # Perform reset
            with get_db_connection() as conn:
                conn.execute('''UPDATE licenses SET hwid = 'UNBOUND', last_hwid_reset = ? WHERE id = ?''', 
                            (current_time, license_id))
            
            embed = discord.Embed(
                title="✅ HWID Reset Successful",
                description="Your HWID has been reset!\nLaunch the script on your new PC to bind it.",
                color=0x55FF55
            )
            embed.add_field(name="Next Reset Available", value=f"In {cooldown_days} days", inline=False)
            await interaction.followup.send(embed=embed, ephemeral=True)
        except Exception as e:
            await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)
    
    @discord.ui.button(label="Version", emoji="ℹ️", style=discord.ButtonStyle.secondary, custom_id="panel_version")
    async def version_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer(ephemeral=True)
        try:
            embed = discord.Embed(
                title="ℹ️ PXHB Script Version",
                color=0x5865F2
            )
            embed.add_field(name="Current Version", value=f"**v{SCRIPT_VERSION}**", inline=True)
            embed.add_field(name="Last Updated", value=LAST_UPDATE, inline=True)
            embed.add_field(name="Changelog", value="\n".join([f"• {item}" for item in CHANGELOG]), inline=False)
            embed.set_footer(text="If your script is outdated, click 'Get Script' again.")
            
            await interaction.followup.send(embed=embed, ephemeral=True)
        except Exception as e:
            await interaction.followup.send(f"❌ Error: {str(e)}", ephemeral=True)

@bot.tree.command(name="panel", description="Send the PXHB control panel embed (Owner Only)")
async def panel(interaction: discord.Interaction):
    if not is_owner(interaction):
        await interaction.response.send_message("❌ This command is restricted to **Owners**.", ephemeral=True)
        return
    
    embed = discord.Embed(
        title="PX HB",
        description="\nAll licenses are HWID-bound, so don't try to share your script or YOU WILL BE BLACKLISTED.",
        color=5814783
    )
    
    view = PanelView()
    await interaction.response.send_message(embed=embed, view=view)

# Register persistent view on bot startup
@bot.event
async def on_ready():
    print(f'Logged in as {bot.user} (ID: {bot.user.id})')
    
    # Register persistent view for panel buttons
    bot.add_view(PanelView())
    
    try:
        synced = await bot.tree.sync()
        print(f'Synced {len(synced)} commands')
    except Exception as e:
        print(f'Sync error: {e}')
    
    # Start background tasks
    check_expirations.start()
    asyncio.create_task(start_webhook_server())

# Run Bot
if __name__ == "__main__":
    if TOKEN:
        bot.run(TOKEN)
    else:
        print("Error: DISCORD_TOKEN not found in .env")