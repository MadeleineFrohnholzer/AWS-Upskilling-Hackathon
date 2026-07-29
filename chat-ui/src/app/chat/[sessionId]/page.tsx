'use client';

import { useEffect } from 'react';
import { use } from 'react';
import { TopBar } from '@/components/layout/TopBar';
import { MessageList } from '@/components/chat/MessageList';
import { ChatInput } from '@/components/chat/ChatInput';
import { useChatSession } from '@/hooks/useChatSession';
import type { Message } from '@/types/chat';

interface PageProps {
  params: Promise<{ sessionId: string }>;
}

export default function ChatPage({ params }: PageProps) {
  const { sessionId } = use(params);
  const { messages, isLoading, sendMessage, setMessages } = useChatSession(sessionId);

  useEffect(() => {
    fetch(`/api/history/${sessionId}`)
      .then((r) => r.json())
      .then((data) => {
        const items: Message[] = (data.items ?? []).map((item: {
          timestamp: string;
          role: 'user' | 'assistant';
          message: string;
          citations?: Array<{ source: string; page?: number; excerpt?: string }>;
        }) => ({
          id: item.timestamp,
          role: item.role,
          content: item.message,
          citations: item.citations ?? [],
        }));
        setMessages(items);
      })
      .catch(() => {});
  }, [sessionId, setMessages]);

  return (
    <div className="flex flex-col h-screen bg-background">
      <TopBar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <MessageList messages={messages} isLoading={isLoading} />
      </div>
      <div className="border-t border-border p-4 pb-6 px-4">
        <div className="max-w-3xl mx-auto">
          <ChatInput onSubmit={sendMessage} isLoading={isLoading} />
        </div>
      </div>
    </div>
  );
}
