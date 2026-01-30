'use client';

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { communityConfigs } from "@/lib/data";
import { ArrowUp, PlusCircle, MessageSquare } from "lucide-react";
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

export default function CommunityPage() {
  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <h1 className="text-3xl font-bold tracking-tight">Community Configs</h1>
          <p className="text-muted-foreground">Share and discover the best script configurations.</p>
        </div>
        <Dialog>
          <DialogTrigger asChild>
            <Button>
              <PlusCircle className="mr-2 h-4 w-4" />
              Share Config
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[425px]">
            <DialogHeader>
              <DialogTitle>Share Configuration</DialogTitle>
              <DialogDescription>
                Share your script configuration with the community.
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="title" className="text-right">
                  Title
                </Label>
                <Input id="title" placeholder="e.g., Aggressive Reaper Setup" className="col-span-3" />
              </div>
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="script" className="text-right">
                  Script
                </Label>
                <Input id="script" placeholder="e.g., Reaper" className="col-span-3" />
              </div>
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="description" className="text-right">
                  Description
                </Label>
                <Textarea id="description" placeholder="Describe your configuration..." className="col-span-3" />
              </div>
              <div className="grid grid-cols-4 items-center gap-4">
                <Label htmlFor="config" className="text-right">
                  Config
                </Label>
                <Textarea id="config" placeholder="Paste your config code here" className="col-span-3 font-code" />
              </div>
            </div>
            <DialogFooter>
              <Button type="submit">Share</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {communityConfigs.map((config) => (
          <Card key={config.id} className="flex flex-col bg-card/50 backdrop-blur-sm">
            <CardHeader>
              <CardTitle>{config.title}</CardTitle>
              <CardDescription>for <span className="font-semibold text-accent">{config.scriptName}</span> by <span className="font-semibold">{config.author}</span></CardDescription>
            </CardHeader>
            <CardContent className="flex-grow">
              <p className="text-muted-foreground">{config.description}</p>
            </CardContent>
            <CardFooter className="flex justify-between items-center">
              <div className="flex items-center gap-2 text-muted-foreground">
                <Button variant="ghost" size="icon" className="h-8 w-8 text-green-400 hover:bg-green-500/10 hover:text-green-300">
                    <ArrowUp className="h-4 w-4" />
                </Button>
                <span className="font-bold">{config.upvotes}</span>
              </div>
              <Dialog>
                <DialogTrigger asChild>
                  <Button variant="outline">View Config</Button>
                </DialogTrigger>
                 <DialogContent className="sm:max-w-2xl">
                    <DialogHeader>
                        <DialogTitle>{config.title}</DialogTitle>
                        <DialogDescription>
                            Configuration for {config.scriptName} by {config.author}.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="mt-4 rounded-md bg-muted p-4">
                        <pre className="text-sm text-foreground whitespace-pre-wrap font-code">
                            <code>{config.configData}</code>
                        </pre>
                    </div>
                     <DialogFooter>
                        <DialogClose asChild>
                            <Button type="button" variant="secondary">Close</Button>
                        </DialogClose>
                        <Button type="button">Copy</Button>
                    </DialogFooter>
                </DialogContent>
              </Dialog>
            </CardFooter>
          </Card>
        ))}
      </div>
    </div>
  );
}
