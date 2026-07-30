import { useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import type { Message } from '@/types/chat';

export function useChatSession(initialSessionId?: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [sessionId] = useState<string>(
    initialSessionId ?? crypto.randomUUID()
  );
  const router = useRouter();

  const sendMessage = useCallback(
    async (text: string) => {
      const userMsg: Message = {
        id: crypto.randomUUID(),
        role: 'user',
        content: text,
        citations: [],
      };

      setMessages((prev) => [...prev, userMsg]);
      setIsLoading(true);

      try {
        const res = await fetch('/api/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ sessionId, message: text }),
        });

        const contentType = res.headers.get('content-type') ?? '';
        if (res.redirected || !contentType.includes('application/json')) {
          window.location.href = '/';
          return;
        }

        const data = await res.json();

        const assistantMsg: Message = {
          id: crypto.randomUUID(),
          role: 'assistant',
          content: data.message ?? '',
          citations: data.citations ?? [],
        };

        setMessages((prev) => [...prev, assistantMsg]);

        if (!initialSessionId) {
          router.push(`/chat/${sessionId}`);
        }
      } catch (err) {
        console.error('Send error:', err);
        const errMsg: Message = {
          id: crypto.randomUUID(),
          role: 'assistant',
          content: 'Sorry, something went wrong. Please try again.',
          citations: [],
        };
        setMessages((prev) => [...prev, errMsg]);
      } finally {
        setIsLoading(false);
      }
    },
    [sessionId, initialSessionId, router]
  );

  return { messages, isLoading, sessionId, sendMessage, setMessages };
}
