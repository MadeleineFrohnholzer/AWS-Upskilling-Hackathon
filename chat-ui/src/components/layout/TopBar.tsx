'use client';

import { useEffect, useState } from 'react';
import { useTheme } from 'next-themes';
import { Sun, Moon, Settings } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { SettingsSheet } from '@/components/settings/SettingsSheet';
import { useSidebar } from '@/components/providers/SidebarProvider';

function getInitials(email: string): string {
  const local = email.split('@')[0];
  const parts = local.split(/[._-]/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return local.slice(0, 2).toUpperCase();
}

export function TopBar() {
  const appName = process.env.NEXT_PUBLIC_APP_NAME ?? 'Knowledge Assistant';
  const { theme, setTheme } = useTheme();
  const { collapsed } = useSidebar();
  const [initials, setInitials] = useState('U');
  const [settingsOpen, setSettingsOpen] = useState(false);

  useEffect(() => {
    fetch('/api/me')
      .then((r) => r.json())
      .then((data) => { if (data.email) setInitials(getInitials(data.email)); })
      .catch(() => {});
  }, []);

  return (
    <>
      <div className={`h-12 border-b border-border flex items-center justify-between px-4 bg-background pl-16 md:pl-4 transition-all duration-300`}>
        <Badge variant="outline" className="text-muted-foreground border-border">
          {appName}
        </Badge>
        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            className="text-muted-foreground hover:text-[#A100FF] hover:bg-transparent"
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            aria-label="Toggle theme"
          >
            {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="text-muted-foreground hover:text-[#A100FF] hover:bg-transparent"
            onClick={() => setSettingsOpen(true)}
            aria-label="Settings"
          >
            <Settings className="h-4 w-4" />
          </Button>
          <Avatar className="w-7 h-7 ml-1 cursor-pointer" onClick={() => setSettingsOpen(true)}>
            <AvatarFallback className="bg-[#A100FF] text-white text-xs">{initials}</AvatarFallback>
          </Avatar>
        </div>
      </div>

      <SettingsSheet open={settingsOpen} onOpenChange={setSettingsOpen} />
    </>
  );
}
