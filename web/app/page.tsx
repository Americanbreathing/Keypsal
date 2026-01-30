import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { DiscordIcon } from '@/components/icons/discord-icon';
import { Logo } from '@/components/logo';

export default function LoginPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8 bg-background">
      <div className="flex flex-col items-center justify-center space-y-8 rounded-xl bg-card/50 backdrop-blur-sm border border-border p-10 sm:p-12 shadow-2xl shadow-primary/10 w-full max-w-md">
        <Logo />
        <div className="text-center space-y-2">
          <h1 className="font-headline text-3xl sm:text-4xl font-bold tracking-tighter">
            Welcome to the Portal
          </h1>
          <p className="text-muted-foreground max-w-sm">
            Access your scripts, configurations, and manage your account.
          </p>
        </div>
        <Button asChild className="w-full max-w-xs group bg-primary hover:bg-primary/90 text-primary-foreground" size="lg">
          <Link href="/dashboard">
            <DiscordIcon className="h-6 w-6 mr-2 transition-transform group-hover:scale-110" />
            Login with Discord
          </Link>
        </Button>
      </div>
    </main>
  );
}
