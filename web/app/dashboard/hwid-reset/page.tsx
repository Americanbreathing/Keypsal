'use client';

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
import { Progress } from "@/components/ui/progress";
import { hwidResets } from "@/lib/data";
import { RotateCw } from "lucide-react";
import { useState } from "react";

export default function HwidResetPage() {
  const [resets, setResets] = useState(hwidResets);
  const resetsRemaining = resets.total - resets.used;
  const progressValue = (resetsRemaining / resets.total) * 100;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">HWID Reset</h1>
        <p className="text-muted-foreground">Manage your Hardware ID binding here.</p>
      </div>

      <Card className="max-w-2xl mx-auto bg-card/50 backdrop-blur-sm">
        <CardHeader>
          <CardTitle>Reset Your Hardware ID</CardTitle>
          <CardDescription>
            You can reset your HWID a limited number of times. Use this if you&apos;ve changed your PC hardware. This action cannot be undone.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <p className="text-sm font-medium">Resets Remaining: {resetsRemaining} / {resets.total}</p>
            <Progress value={progressValue} aria-label={`${resetsRemaining} of ${resets.total} resets remaining`} />
          </div>

          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                variant="destructive"
                disabled={resetsRemaining <= 0}
                className="w-full sm:w-auto"
              >
                <RotateCw className="mr-2 h-4 w-4" />
                Reset HWID
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Are you absolutely sure?</AlertDialogTitle>
                <AlertDialogDescription>
                  This will use one of your available HWID resets. This action is permanent and cannot be undone. Are you sure you want to proceed?
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction onClick={() => setResets(prev => ({ ...prev, used: prev.used + 1 }))}>
                  Continue
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </CardContent>
      </Card>
    </div>
  );
}
