'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { Session } from '@/types/chat';

function groupSessions(sessions: Session[]) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today.getTime() - 86400000);
  const thisWeek = new Date(today.getTime() - 7 * 86400000);

  const groups: Record<string, Session[]> = {
    Today: [],
    Yesterday: [],
    'This Week': [],
    Older: [],
  };

  for (const session of sessions) {
    const d = new Date(session.lastMessageAt);
    if (d >= today) groups['Today'].push(session);
    else if (d >= yesterday) groups['Yesterday'].push(session);
    else if (d >= thisWeek) groups['This Week'].push(session);
    else groups['Older'].push(session);
  }

  return groups;
}

export function ChatHistoryList() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const params = useParams();
  const router = useRouter();
  const activeSessionId = params?.sessionId as string | undefined;

  useEffect(() => {
    fetch('/api/sessions')
      .then((r) => r.json())
      .then((data) => setSessions(data.sessions ?? []))
      .catch(() => setSessions([]))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="p-2 space-y-1">
        {[...Array(4)].map((_, i) => (
          <Skeleton key={i} className="h-8 bg-[#1A1A1A] rounded mx-2 my-1" />
        ))}
      </div>
    );
  }

  const groups = groupSessions(sessions);

  return (
    <div className="overflow-y-auto h-full py-2">
      {Object.entries(groups).map(([label, items]) => {
        if (items.length === 0) return null;
        return (
          <div key={label}>
            <p className="text-[#888888] text-xs font-semibold uppercase tracking-widest px-3 mt-4 mb-1">
              {label}
            </p>
            {items.map((session) => {
              const isActive = session.sessionId === activeSessionId;
              return (
                <Button
                  key={session.sessionId}
                  variant="ghost"
                  className={`w-full justify-start text-sm px-3 py-2 h-auto truncate ${
                    isActive
                      ? 'bg-[rgba(161,0,255,0.08)] border-l-2 border-[#A100FF] text-white'
                      : 'text-[#888888] hover:text-white hover:bg-[#1A1A1A]'
                  }`}
                  onClick={() => router.push(`/chat/${session.sessionId}`)}
                >
                  <span className="truncate">{session.title}</span>
                </Button>
              );
            })}
          </div>
        );
      })}
    </div>
  );
}
