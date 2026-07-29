'use client';

import { useEffect, useState } from 'react';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';

function getInitials(email: string): string {
  const parts = email.split('@')[0].split(/[._-]/);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return email.slice(0, 2).toUpperCase();
}

export function UserIdentity() {
  const [email, setEmail] = useState<string>('dev@local');

  useEffect(() => {
    fetch('/api/me')
      .then((r) => r.json())
      .then((data) => setEmail(data.email ?? 'dev@local'))
      .catch(() => setEmail('dev@local'));
  }, []);

  return (
    <div className="flex items-center gap-2">
      <Avatar className="w-7 h-7">
        <AvatarFallback className="bg-[#A100FF] text-white text-xs">
          {getInitials(email)}
        </AvatarFallback>
      </Avatar>
      <span className="text-[#888888] text-sm truncate">{email}</span>
    </div>
  );
}
