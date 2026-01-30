import sqlite3 from 'sqlite3';
import { open, Database } from 'sqlite';
import path from 'path';
import fs from 'fs';

let db: Database | null = null;

export async function getDB() {
    if (db) return db;

    // Use the same persistence path as the bot
    const DATA_DIR = process.env.DATA_DIR || (fs.existsSync('/app/data') ? '/app/data' : '.');
    const DB_PATH = path.join(DATA_DIR, 'licenses.db');

    db = await open({
        filename: DB_PATH,
        driver: sqlite3.Database
    });

    // Enable WAL mode for concurrency with the Discord bot
    await db.exec('PRAGMA journal_mode=WAL;');
    await db.exec('PRAGMA synchronous=NORMAL;');

    // Create ALL tables if they don't exist (same as bot)
    await db.exec(`
        CREATE TABLE IF NOT EXISTS licenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            discord_id TEXT NOT NULL,
            discord_name TEXT NOT NULL,
            hwid TEXT DEFAULT 'UNBOUND',
            status TEXT DEFAULT 'pending',
            expires_at INTEGER NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            last_hwid_reset INTEGER DEFAULT NULL
        )
    `);

    await db.exec(`
        CREATE TABLE IF NOT EXISTS admins (
            discord_id TEXT PRIMARY KEY,
            discord_name TEXT NOT NULL,
            added_at INTEGER NOT NULL
        )
    `);

    await db.exec(`
        CREATE TABLE IF NOT EXISTS configs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            user_name TEXT NOT NULL,
            script_name TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            data TEXT NOT NULL,
            upvotes INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
        )
    `);

    return db;
}
