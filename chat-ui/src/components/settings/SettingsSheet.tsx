'use client';

import { useEffect, useState } from 'react';
import { useTheme } from 'next-themes';
import { Sun, Moon } from 'lucide-react';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';

function getInitials(email: string): string {
  const local = email.split('@')[0];
  const parts = local.split(/[._-]/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return local.slice(0, 2).toUpperCase();
}

interface SettingsSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function SettingsSheet({ open, onOpenChange }: SettingsSheetProps) {
  const { theme, setTheme } = useTheme();
  const [email, setEmail] = useState('');

  useEffect(() => {
    if (!open) return;
    fetch('/api/me')
      .then((r) => r.json())
      .then((data) => setEmail(data.email ?? ''))
      .catch(() => {});
  }, [open]);

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="right"
        className="w-full sm:w-[380px] bg-background border-l border-border text-foreground flex flex-col"
      >
        <SheetHeader>
          <SheetTitle className="text-foreground">Settings</SheetTitle>
        </SheetHeader>

        <div className="mt-6 space-y-6 flex-1 overflow-y-auto pr-1">

          {/* Appearance */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-3">
              Appearance
            </h3>
            <div className="flex gap-2">
              <button
                onClick={() => setTheme('light')}
                className={`flex flex-1 items-center justify-center gap-2 rounded-lg border px-4 py-3 text-sm font-medium transition-colors ${
                  theme === 'light'
                    ? 'border-[#A100FF] bg-[rgba(161,0,255,0.06)] text-[#A100FF]'
                    : 'border-border text-muted-foreground hover:border-[#A100FF] hover:text-[#A100FF]'
                }`}
              >
                <Sun className="h-4 w-4" />
                Light
              </button>
              <button
                onClick={() => setTheme('dark')}
                className={`flex flex-1 items-center justify-center gap-2 rounded-lg border px-4 py-3 text-sm font-medium transition-colors ${
                  theme === 'dark'
                    ? 'border-[#A100FF] bg-[rgba(161,0,255,0.06)] text-[#A100FF]'
                    : 'border-border text-muted-foreground hover:border-[#A100FF] hover:text-[#A100FF]'
                }`}
              >
                <Moon className="h-4 w-4" />
                Dark
              </button>
            </div>
          </section>

          <Separator className="bg-border" />

          {/* Account */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-3">
              Account
            </h3>
            {email ? (
              <div className="flex items-center gap-3 rounded-lg border border-border bg-card p-3">
                <Avatar className="h-9 w-9 flex-shrink-0">
                  <AvatarFallback className="bg-[#A100FF] text-white text-xs">
                    {getInitials(email)}
                  </AvatarFallback>
                </Avatar>
                <div className="min-w-0">
                  <p className="text-foreground text-sm font-medium truncate">{email}</p>
                  <p className="text-muted-foreground text-xs mt-0.5">Accenture · Entra ID SSO</p>
                </div>
              </div>
            ) : (
              <div className="h-16 rounded-lg border border-border bg-card animate-pulse" />
            )}
          </section>

          <Separator className="bg-border" />

          {/* About */}
          <section>
            <h3 className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-3">
              About
            </h3>
            <div className="space-y-1.5 text-sm text-muted-foreground">
              <div className="flex justify-between">
                <span>Application</span>
                <span className="text-foreground">
                  {process.env.NEXT_PUBLIC_APP_NAME ?? 'Knowledge Assistant'}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Model</span>
                <span className="text-foreground">Amazon Bedrock · Claude</span>
              </div>
              <div className="flex justify-between">
                <span>Built by</span>
                <span className="text-foreground">Accenture</span>
              </div>
            </div>
          </section>

        </div>
      </SheetContent>
    </Sheet>
  );
}
