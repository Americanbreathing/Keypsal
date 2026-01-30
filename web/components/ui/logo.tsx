import { ShieldHalf } from 'lucide-react';
import Link from 'next/link';
import { cn } from '@/lib/utils';

export function Logo({ className }: { className?: string }) {
  return (
    <Link href="/dashboard" className={cn("flex items-center gap-2 group", className)}>
      <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-primary-foreground transition-all group-hover:scale-105 group-hover:shadow-lg group-hover:shadow-primary/30">
        <ShieldHalf className="h-5 w-5" />
      </div>
      <span className="font-headline text-lg font-bold tracking-tight hidden group-data-[collapsible=icon]:hidden">
        PX HB
      </span>
    </Link>
  );
}
