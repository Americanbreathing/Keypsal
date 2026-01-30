import { getServerSession } from "next-auth/next";
import { NextResponse } from "next/server";
import { getDB } from "@/lib/db";
import { authOptions } from "@/app/api/auth/[...nextauth]/route";

export async function GET() {
    const session = await getServerSession(authOptions) as any;

    if (!session || !session.user || !session.user.id) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    try {
        const db = await getDB();
        const discordId = session.user.id;

        const licenses = await db.all(
            'SELECT * FROM licenses WHERE discord_id = ? ORDER BY created_at DESC',
            [discordId.toString()]
        );

        return NextResponse.json({ licenses });
    } catch (error) {
        console.error("Database error:", error);
        return NextResponse.json({ error: "Database error" }, { status: 500 });
    }
}
