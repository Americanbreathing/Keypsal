'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useSession, signOut } from 'next-auth/react';
import {
    SidebarProvider,
    Sidebar,
    SidebarHeader,
    SidebarContent,
    SidebarMenu,
    SidebarMenuItem,
    SidebarMenuButton,
    SidebarFooter,
    SidebarInset,
    SidebarTrigger,
} from '@/components/ui/sidebar';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import {
    LayoutDashboard,
    Download,
    Users,
    RotateCw,
    Cpu,
    LogOut,
    Menu,
} from 'lucide-react';
import React from 'react';

const navItems = [
    { href: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
    { href: '/dashboard/scripts', icon: Download, label: 'My Scripts' },
    { href: '/dashboard/community', icon: Users, label: 'Community' },
    { href: '/dashboard/hwid-reset', icon: RotateCw, label: 'HWID Reset' },
    { href: '/dashboard/ai-suggester', icon: Cpu, label: 'AI Suggester' },
];

export default function DashboardLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const pathname = usePathname();
    const { data: session } = useSession();
    const userAvatar = session?.user?.image || null;

    return (
        <SidebarProvider>
            <Sidebar>
                <SidebarContent>
                    <SidebarMenu>
                        {navItems.map((item) => (
                            <SidebarMenuItem key={item.href}>
                                <SidebarMenuButton
                                    asChild
                                    isActive={
                                        item.href === '/dashboard'
                                            ? pathname === item.href
                                            : pathname.startsWith(item.href) && item.href !== '/dashboard'
                                    }
                                    tooltip={{ children: item.label }}
                                    className="group/button"
                                >
                                    <Link href={item.href}>
                                        <item.icon className="transition-colors group-data-[active=true]/button:text-accent group-data-[active=true]/button:drop-shadow-[0_0_5px_hsl(var(--accent))]" />
                                        <span>{item.label}</span>
                                    </Link>
                                </SidebarMenuButton>
                            </SidebarMenuItem>
                        ))}
                    </SidebarMenu>
                </SidebarContent>
                <SidebarFooter className="max-md:hidden">
                    <div className="flex items-center gap-3 p-2">
                        <Avatar className="h-9 w-9">
                            <AvatarImage src={userAvatar || undefined} />
                            <AvatarFallback>{session?.user?.name?.charAt(0) || 'U'}</AvatarFallback>
                        </Avatar>
                        <div className="flex flex-col group-data-[collapsible=icon]:hidden overflow-hidden">
                            <span className="text-sm font-medium truncate">{session?.user?.name || 'Guest'}</span>
                            <span className="text-xs text-muted-foreground truncate">
                                {session?.user?.email || 'Not logged in'}
                            </span>
                        </div>
                    </div>
                    <SidebarMenu>
                        <SidebarMenuItem>
                            <SidebarMenuButton asChild onClick={() => signOut()}>
                                <button className="flex items-center w-full">
                                    <LogOut className="mr-2 h-4 w-4" />
                                    <span>Logout</span>
                                </button>
                            </SidebarMenuButton>
                        </SidebarMenuItem>
                    </SidebarMenu>
                </SidebarFooter>
            </Sidebar>
            <SidebarInset>
                <header className="sticky top-0 z-10 flex h-14 items-center gap-4 border-b bg-background/80 px-4 backdrop-blur-sm sm:h-16 sm:px-6 md:hidden">
                    <SidebarTrigger asChild>
                        <Button size="icon" variant="outline">
                            <Menu className="h-5 w-5" />
                            <span className="sr-only">Toggle Menu</span>
                        </Button>
                    </SidebarTrigger>
                </header>
                <main className="p-4 sm:p-6 lg:p-8 w-full max-w-7xl mx-auto">{children}</main>
            </SidebarInset>
        </SidebarProvider>
    );
}
