'use client';

import { useState, useEffect } from "react";
import { useSession } from "next-auth/react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowUp, PlusCircle, Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
  DialogClose
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "@/hooks/use-toast";

export default function CommunityPage() {
  const { data: session } = useSession();
  const [configs, setConfigs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [sharing, setSharing] = useState(false);

  // Form state
  const [title, setTitle] = useState("");
  const [scriptName, setScriptName] = useState("");
  const [description, setDescription] = useState("");
  const [configData, setConfigData] = useState("");

  useEffect(() => {
    fetchConfigs();
  }, []);

  const fetchConfigs = async () => {
    try {
      const res = await fetch("/api/configs");
      const data = await res.json();
      if (data.configs) setConfigs(data.configs);
    } catch (err) {
      console.error("Failed to fetch configs");
    } finally {
      setLoading(false);
    }
  };

  const handleShare = async () => {
    if (!session) {
      toast({ variant: "destructive", title: "Wait!", description: "You must be logged in to share configs." });
      return;
    }

    if (!title || !scriptName || !configData) {
      toast({ variant: "destructive", title: "Error", description: "Please fill in all required fields." });
      return;
    }

    setSharing(true);
    try {
      const res = await fetch("/api/configs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title, script_name: scriptName, description, data: configData }),
      });

      if (res.ok) {
        toast({ title: "Success", description: "Your config has been shared!" });
        setTitle(""); setScriptName(""); setDescription(""); setConfigData("");
        fetchConfigs();
      } else {
        const error = await res.json();
        toast({ variant: "destructive", title: "Error", description: error.error });
      }
    } catch (err) {
      toast({ variant: "destructive", title: "Error", description: "Failed to upload config." });
    } finally {
      setSharing(false);
    }
  };

  if (loading) {
    return (
      <div className="flex h-[400px] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-8 p-4">
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <h1 className="text-3xl font-bold tracking-tight">Community Configs</h1>
          <p className="text-muted-foreground">Share and discover the best script configurations.</p>
        </div>

        {session ? (
          <Dialog>
            <DialogTrigger asChild>
              <Button>
                <PlusCircle className="mr-2 h-4 w-4" />
                Share Config
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px] bg-card border-border">
              <DialogHeader>
                <DialogTitle>Share Configuration</DialogTitle>
                <DialogDescription>
                  Share your script configuration with the community.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4 text-foreground">
                <div className="space-y-2">
                  <Label htmlFor="title">Title *</Label>
                  <Input id="title" value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g., Aggressive Reaper Setup" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="script">Script *</Label>
                  <Input id="script" value={scriptName} onChange={(e) => setScriptName(e.target.value)} placeholder="e.g., Reaper" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="description">Description</Label>
                  <Textarea id="description" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Describe your configuration..." />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="config">Config Data *</Label>
                  <Textarea id="config" value={configData} onChange={(e) => setConfigData(e.target.value)} placeholder="Paste your config JSON here" className="font-mono h-32" />
                </div>
              </div>
              <DialogFooter>
                <Button onClick={handleShare} disabled={sharing}>
                  {sharing && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Share Config
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : (
          <p className="text-sm text-yellow-500 font-medium bg-yellow-500/10 px-3 py-1 rounded-md border border-yellow-500/20">
            Log in to share configs
          </p>
        )}
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {configs.length === 0 ? (
          <p className="text-center col-span-full py-12 text-muted-foreground border border-dashed rounded-lg">
            No community configs yet. Be the first to share one!
          </p>
        ) : (
          configs.map((config) => (
            <Card key={config.id} className="flex flex-col bg-card/50 backdrop-blur-sm border-border hover:border-primary/50 transition-colors">
              <CardHeader>
                <CardTitle className="text-xl">{config.title}</CardTitle>
                <CardDescription>
                  for <span className="font-semibold text-primary">{config.script_name}</span> by <span className="font-semibold">{config.user_name}</span>
                </CardDescription>
              </CardHeader>
              <CardContent className="flex-grow">
                <p className="text-sm text-muted-foreground line-clamp-3">{config.description || "No description provided."}</p>
              </CardContent>
              <CardFooter className="flex justify-between items-center pt-4 border-t border-border">
                <div className="flex items-center gap-2 text-muted-foreground">
                  <Button variant="ghost" size="icon" className="h-8 w-8 text-green-400 hover:bg-green-500/10 hover:text-green-300">
                    <ArrowUp className="h-4 w-4" />
                  </Button>
                  <span className="font-bold">{config.upvotes}</span>
                </div>

                <Dialog>
                  <DialogTrigger asChild>
                    <Button variant="outline" size="sm">View Config</Button>
                  </DialogTrigger>
                  <DialogContent className="sm:max-w-xl bg-card border-border">
                    <DialogHeader>
                      <DialogTitle>{config.title}</DialogTitle>
                      <DialogDescription>
                        Configuration for {config.script_name} by {config.user_name}.
                      </DialogDescription>
                    </DialogHeader>
                    <div className="mt-4 rounded-md bg-secondary/30 p-4 border border-border">
                      <pre className="text-xs text-foreground whitespace-pre-wrap font-mono max-h-[300px] overflow-y-auto">
                        <code>{config.data}</code>
                      </pre>
                    </div>
                    <DialogFooter>
                      <DialogClose asChild>
                        <Button type="button" variant="secondary">Close</Button>
                      </DialogClose>
                      <Button
                        type="button"
                        onClick={() => {
                          navigator.clipboard.writeText(config.data);
                          toast({ title: "Copied!", description: "Config data copied to clipboard." });
                        }}
                      >
                        Copy Config
                      </Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </CardFooter>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
