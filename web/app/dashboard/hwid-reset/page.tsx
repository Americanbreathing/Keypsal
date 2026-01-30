'use client';

import { useEffect, useState } from "react";
import { useSession } from "next-auth/react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { RotateCw, Loader2, ShieldCheck } from "lucide-react";
import { toast } from "@/hooks/use-toast";

interface License {
  id: number;
  key: string;
  hwid: string;
  status: string;
  last_hwid_reset: number;
  expires_at: number;
}

export default function HwidResetPage() {
  const { data: session } = useSession();
  const [licenses, setLicenses] = useState<License[]>([]);
  const [loading, setLoading] = useState(true);
  const [resetting, setResetting] = useState<number | null>(null);

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
    setResetting(licenseId);
    try {
      const res = await fetch("/api/user/reset-hwid", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ licenseId }),
      });
      const data = await res.json();

      if (res.ok) {
        toast({ title: "Success", description: data.message });
        fetchLicenses(); // Refresh data
      } else {
        toast({ variant: "destructive", title: "Error", description: data.error });
      }
    } catch (err) {
      toast({ variant: "destructive", title: "Error", description: "Request failed" });
    } finally {
      setResetting(null);
    }
  };

  const getCooldownRemaining = (lastReset: number) => {
    if (!lastReset) return null;
    const now = Math.floor(Date.now() / 1000);
    const cooldownEnd = lastReset + (24 * 60 * 60);
    if (now >= cooldownEnd) return null;
    const remaining = cooldownEnd - now;
    const hours = Math.floor(remaining / 3600);
    const minutes = Math.floor((remaining % 3600) / 60);
    return `${hours}h ${minutes}m`;
  };

  if (loading) {
    return (
      <div className="flex h-[400px] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">HWID Reset</h1>
        <p className="text-muted-foreground">Manage your Hardware ID bindings here.</p>
      </div>

      {licenses.length === 0 ? (
        <Card className="bg-card/50 backdrop-blur-sm">
          <CardContent className="py-12 text-center">
            <p className="text-muted-foreground">No licenses found. Get a key from Discord first!</p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4">
          {licenses.map((license) => {
            const cooldown = getCooldownRemaining(license.last_hwid_reset);
            const canReset = !cooldown && license.hwid && license.hwid !== "UNBOUND";

            return (
              <Card key={license.id} className="bg-card/50 backdrop-blur-sm">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <ShieldCheck className="h-5 w-5 text-primary" />
                      License #{license.id}
                    </CardTitle>
                    <Badge variant={license.status === 'active' ? 'default' : 'secondary'} className="capitalize">
                      {license.status}
                    </Badge>
                  </div>
                  <CardDescription className="font-mono text-xs">
                    {license.key.substring(0, 30)}...
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <div className="space-y-1">
                      <p className="text-sm">
                        <span className="text-muted-foreground">Current HWID: </span>
                        <span className="font-mono">{license.hwid || "Not Bound"}</span>
                      </p>
                      {cooldown && (
                        <p className="text-sm text-yellow-500">
                          Cooldown: {cooldown} remaining
                        </p>
                      )}
                    </div>

                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <Button
                          variant="destructive"
                          disabled={!canReset || resetting === license.id}
                        >
                          {resetting === license.id ? (
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                          ) : (
                            <RotateCw className="mr-2 h-4 w-4" />
                          )}
                          Reset HWID
                        </Button>
                      </AlertDialogTrigger>
                      <AlertDialogContent>
                        <AlertDialogHeader>
                          <AlertDialogTitle>Are you sure?</AlertDialogTitle>
                          <AlertDialogDescription>
                            This will unbind your current hardware. You will need to re-activate
                            the script on your new device. There is a 24-hour cooldown after each reset.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Cancel</AlertDialogCancel>
                          <AlertDialogAction onClick={() => handleResetHWID(license.id)}>
                            Confirm Reset
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
