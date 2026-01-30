"use client";

import { useEffect, useState } from "react";
import { useSession } from "next-auth/react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { RefreshCcw, ShieldCheck } from "lucide-react";
import { toast } from "@/hooks/use-toast";

export default function MyScriptsPage() {
    const { data: session } = useSession();
    const [licenses, setLicenses] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [resetting, setResetting] = useState<string | null>(null);

    useEffect(() => {
        if (session) {
            fetchLicenses();
        }
    }, [session]);

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

    if (loading) {
        return (
            <div className="flex h-full items-center justify-center">
                <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary"></div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-3xl font-bold tracking-tight">My Scripts</h1>
                <p className="text-muted-foreground">Manage your active script licenses.</p>
            </div>

            <Card className="bg-card/50 backdrop-blur-sm border-border">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <ShieldCheck className="text-primary" /> Active Licenses
                    </CardTitle>
                    <CardDescription>Your purchased script keys</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                    {licenses.length === 0 ? (
                        <p className="text-center py-8 text-muted-foreground">No licenses found. Head over to the Discord to get one!</p>
                    ) : (
                        licenses.map((lic) => (
                            <div key={lic.id} className="p-4 rounded-lg bg-secondary/30 border border-border flex items-center justify-between">
                                <div className="space-y-1">
                                    <div className="flex items-center gap-2">
                                        <span className="font-mono text-sm">{lic.key}</span>
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
        </div>
    );
}
