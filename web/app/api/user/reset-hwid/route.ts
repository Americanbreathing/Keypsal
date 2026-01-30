import { getServerSession } from "next-auth/next";
import { NextResponse } from "next/server";
import { getDB } from "@/lib/db";
import { authOptions } from "@/lib/auth";

export async function POST(request: Request) {
    const session = await getServerSession(authOptions) as any;

    if (!session || !session.user || !session.user.id) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    try {
        const { licenseId } = await request.json();
        if (!licenseId) {
            return NextResponse.json({ error: "License ID required" }, { status: 400 });
        }

        const db = await getDB();
        const discordId = session.user.id;

        // Fetch the license to check ownership and cooldown
        const license = await db.get(
            'SELECT id, hwid, last_hwid_reset FROM licenses WHERE id = ? AND discord_id = ?',
            [licenseId, discordId.toString()]
        );

        if (!license) {
            return NextResponse.json({ error: "License not found or access denied" }, { status: 404 });
        }

        const currentTime = Math.floor(Date.now() / 1000);
        const cooldownSeconds = 24 * 60 * 60; // 24 hours

        if (license.last_hwid_reset && (currentTime - license.last_hwid_reset < cooldownSeconds)) {
            const remaining = cooldownSeconds - (currentTime - license.last_hwid_reset);
            const hours = Math.floor(remaining / 3600);
            return NextResponse.json({
                error: `HWID reset on cooldown. Please wait ${hours} hours.`
            }, { status: 429 });
        }

        // Reset HWID
        await db.run(
            "UPDATE licenses SET hwid = 'UNBOUND', status = 'pending', last_hwid_reset = ? WHERE id = ?",
            [currentTime, licenseId]
        );

        return NextResponse.json({ success: true, message: "HWID reset successfully. You can now re-bind in-game." });
    } catch (error) {
        console.error("Reset error:", error);
        return NextResponse.json({ error: "Server error" }, { status: 500 });
    }
}
