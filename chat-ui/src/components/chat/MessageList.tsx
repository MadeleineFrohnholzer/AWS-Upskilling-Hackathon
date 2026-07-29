'use client';

import { useEffect, useRef } from 'react';
import { ScrollArea } from '@/components/ui/scroll-area';
import type { Message } from '@/types/chat';
import { MessageBubble } from './MessageBubble';
import { ThinkingBubble } from './ThinkingBubble';

interface MessageListProps {
  messages: Message[];
  isLoading: boolean;
  userEmail?: string;
}

export function MessageList({ messages, isLoading, userEmail }: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isLoading]);

  return (
    <ScrollArea className="flex-1 px-4">
      <div className="max-w-3xl mx-auto py-4 space-y-2">
        {messages.map((msg) => (
          <MessageBubble key={msg.id} message={msg} userEmail={userEmail} />
        ))}
        {isLoading && <ThinkingBubble />}
        <div ref={bottomRef} />
      </div>
    </ScrollArea>
  );
}
