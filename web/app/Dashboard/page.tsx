"use client";

import { useEffect, useState } from "react";
import { useSession, signOut } from "next-auth/react";
import { useRouter } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Circle, RefreshCcw, LogOut, ShieldCheck } from "lucide-react";
import { toast } from "@/hooks/use-toast";

export default function DashboardPage() {
    const { data: session, status } = useSession();
    const router = useRouter();
    const [licenses, setLicenses] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [resetting, setResetting] = useState<string | null>(null);

    useEffect(() => {
        if (status === "unauthenticated") {
            router.push("/");
        } else if (status === "authenticated") {
            fetchLicenses();
        }
    }, [status]);

    const fetchLicenses = async () => {
        try {
            const res = await fetch("/api/user/licenses");
            const data = await res.json();
            if (data.licenses) setLicenses(data.licenses);
        } catch (err) {
            console.error("Failed to fetch licenses");
        } finally {
            setLoading(false);
        }
    };

    const handleResetHWID = async (licenseId: number) => {
        setResetting(licenseId.toString());
        try {
            const res = await fetch("/api/user/reset-hwid", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ licenseId }),
            });
            const data = await res.json();

            if (res.ok) {
                toast({ title: "Success", description: data.message });
                fetchLicenses();
            } else {
                toast({ variant: "destructive", title: "Error", description: data.error });
            }
        } catch (err) {
            toast({ variant: "destructive", title: "Error", description: "Request failed" });
        } finally {
            setResetting(null);
        }
    };

    if (status === "loading" || loading) {
        return (
            <div className="flex min-h-screen items-center justify-center bg-background">
                <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary"></div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-background p-8">
            <div className="max-w-6xl mx-auto space-y-8">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-4xl font-bold tracking-tight text-foreground">Welcome back, {session?.user?.name}</h1>
                        <p className="text-muted-foreground">Manage your PXHB licenses and hardware bindings.</p>
                    </div>
                    <div className="flex gap-4">
                        <Button variant="outline" onClick={() => signOut()}>
                            <LogOut className="mr-2 h-4 w-4" /> Sign Out
                        </Button>
                    </div>
                </div>

                <div className="grid gap-6 md:grid-cols-2">
                    {/* Main License Card */}
                    <Card className="bg-card/50 backdrop-blur-sm border-border">
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <ShieldCheck className="text-primary" /> My Licenses
                            </CardTitle>
                            <CardDescription>Your active script access keys</CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            {licenses.length === 0 ? (
                                <p className="text-center py-8 text-muted-foreground">No licenses found. Head over to the Discord to get one!</p>
                            ) : (
                                licenses.map((lic) => (
                                    <div key={lic.id} className="p-4 rounded-lg bg-secondary/30 border border-border flex items-center justify-between">
                                        <div className="space-y-1">
                                            <div className="flex items-center gap-2">
                                                <span className="font-mono text-sm">{lic.key.substring(0, 15)}...</span>
                                                <Badge variant={lic.status === 'active' ? 'default' : 'secondary'} className="capitalize">
                                                    {lic.status}
                                                </Badge>
                                            </div>
                                            <p className="text-xs text-muted-foreground">
                                                HWID: <span className="text-foreground">{lic.hwid || "Not Bound"}</span>
                                            </p>
                                        </div>

                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => handleResetHWID(lic.id)}
                                            disabled={resetting === lic.id.toString() || !lic.hwid || lic.hwid === "UNBOUND"}
                                        >
                                            <RefreshCcw className={`mr-2 h-3 w-3 ${resetting === lic.id.toString() ? 'animate-spin' : ''}`} />
                                            Reset HWID
                                        </Button>
                                    </div>
                                ))
                            )}
                        </CardContent>
                    </Card>

                    {/* Script Status Card */}
                    <Card className="bg-card/50 backdrop-blur-sm border-border">
                        <CardHeader>
                            <CardTitle>PX HB Global Status</CardTitle>
                            <CardDescription>Real-time status of our services</CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <div className="flex items-center justify-between p-3 rounded-md bg-green-500/10 border border-green-500/20">
                                <span className="font-medium text-green-400">Main Script</span>
                                <Badge className="bg-green-500/20 text-green-400 border-green-500/30">
                                    <Circle className="mr-2 h-2 w-2 fill-current" /> Undetected
                                </Badge>
                            </div>
                            <div className="flex items-center justify-between p-3 rounded-md bg-green-500/10 border border-green-500/20">
                                <span className="font-medium text-green-400">Webhook Server</span>
                                <Badge className="bg-green-500/20 text-green-400 border-green-500/30">
                                    <Circle className="mr-2 h-2 w-2 fill-current" /> Online
                                </Badge>
                            </div>
                            <div className="p-4 bg-primary/5 rounded-lg border border-primary/20">
                                <h4 className="text-sm font-semibold mb-1">📢 Latest Update</h4>
                                <p className="text-xs text-muted-foreground">V3.2.0: Improved aimbot smoothing and detection bypass. Added stealth mode for QB.</p>
                            </div>
                        </CardContent>
                    </Card>
                </div>
            </div>
        </div>
    );
}
