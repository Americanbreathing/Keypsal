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

    return db;
}
