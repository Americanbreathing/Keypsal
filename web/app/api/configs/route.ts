import { getServerSession } from "next-auth/next";
import { NextResponse } from "next/server";
import { getDB } from "@/lib/db";

export async function GET() {
    try {
        const db = await getDB();
        const configs = await db.all('SELECT * FROM configs ORDER BY upvotes DESC, created_at DESC');
        return NextResponse.json({ configs });
    } catch (error) {
        console.error("Fetch configs error:", error);
        return NextResponse.json({ error: "Database error" }, { status: 500 });
    }
}

export async function POST(request: Request) {
    const session = await getServerSession() as any;

    if (!session || !session.user || !session.user.id) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    try {
        const { script_name, title, description, data } = await request.json();

        if (!script_name || !title || !data) {
            return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
        }

        const db = await getDB();
        const result = await db.run(
            `INSERT INTO configs (user_id, user_name, script_name, title, description, data, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [session.user.id, session.user.name, script_name, title, description, data, Math.floor(Date.now() / 1000)]
        );

        return NextResponse.json({ success: true, configId: result.lastID });
    } catch (error) {
        console.error("Upload config error:", error);
        return NextResponse.json({ error: "Server error" }, { status: 500 });
    }
}
