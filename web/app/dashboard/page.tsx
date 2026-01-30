import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { scripts } from "@/lib/data";
import { cn } from "@/lib/utils";
import { Circle } from "lucide-react";

export default function DashboardPage() {
    const getStatusClass = (status: 'online' | 'down' | 'updating') => {
        switch (status) {
            case 'online':
                return 'bg-green-500/20 text-green-400 border-green-500/30';
            case 'updating':
                return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
            case 'down':
                return 'bg-red-500/20 text-red-400 border-red-500/30';
        }
    };

    const getStatusIconColor = (status: 'online' | 'down' | 'updating') => {
        switch (status) {
            case 'online':
                return 'text-green-500';
            case 'updating':
                return 'text-yellow-500';
            case 'down':
                return 'text-red-500';
        }
    };

    return (
        <div className="space-y-8">
            <div>
                <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
                <p className="text-muted-foreground">Live status of all PX HB scripts.</p>
            </div>

            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                {scripts.map((script) => (
                    <Card key={script.id} className="bg-card/50 backdrop-blur-sm hover:border-primary/50 transition-colors">
                        <CardHeader>
                            <div className="flex items-center justify-between">
                                <CardTitle className="text-xl">{script.name}</CardTitle>
                                <Badge className={cn("capitalize", getStatusClass(script.status))}>
                                    <Circle className={cn("mr-2 h-2 w-2 fill-current", getStatusIconColor(script.status))} />
                                    {script.status}
                                </Badge>
                            </div>
                        </CardHeader>
                        <CardContent>
                            <p className="text-muted-foreground">{script.description}</p>
                        </CardContent>
                    </Card>
                ))}
            </div>
        </div>
    );
}
