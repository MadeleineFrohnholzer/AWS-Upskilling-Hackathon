'use client';

import { useTheme } from 'next-themes';
import { Sun, Moon, Settings } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';

export function TopBar() {
  const appName = process.env.NEXT_PUBLIC_APP_NAME ?? 'Knowledge Assistant';
  const { theme, setTheme } = useTheme();

  return (
    <div className="h-12 border-b border-border flex items-center justify-between px-4 bg-background pl-16 md:pl-4">
      <Badge variant="outline" className="text-muted-foreground border-border">
        {appName}
      </Badge>
      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="icon"
          className="text-muted-foreground hover:text-foreground"
          onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
          aria-label="Toggle theme"
        >
          {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
        </Button>
        <Button variant="ghost" size="icon" className="text-muted-foreground hover:text-foreground">
          <Settings className="h-4 w-4" />
        </Button>
        <Avatar className="w-7 h-7">
          <AvatarFallback className="bg-[#A100FF] text-white text-xs">U</AvatarFallback>
        </Avatar>
      </div>
    </div>
  );
}
