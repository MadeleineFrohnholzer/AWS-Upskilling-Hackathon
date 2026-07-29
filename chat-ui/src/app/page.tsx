'use client';

import { WelcomeScreen } from '@/components/chat/WelcomeScreen';
import { MessageList } from '@/components/chat/MessageList';
import { ChatInput } from '@/components/chat/ChatInput';
import { TopBar } from '@/components/layout/TopBar';
import { useChatSession } from '@/hooks/useChatSession';

export default function HomePage() {
  const { messages, isLoading, sendMessage } = useChatSession();

  return (
    <div className="flex flex-col h-screen bg-black">
      <TopBar />
      {messages.length === 0 ? (
        <div className="flex-1 flex flex-col overflow-hidden">
          <WelcomeScreen onSubmit={sendMessage} isLoading={isLoading} />
        </div>
      ) : (
        <>
          <div className="flex-1 flex flex-col overflow-hidden">
            <MessageList messages={messages} isLoading={isLoading} />
          </div>
          <div className="border-t border-[#333333] p-4">
            <div className="max-w-3xl mx-auto">
              <ChatInput onSubmit={sendMessage} isLoading={isLoading} />
            </div>
          </div>
        </>
      )}
    </div>
  );
}
