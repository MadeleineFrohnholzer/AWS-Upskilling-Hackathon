import { AccentureMark } from '@/components/brand/AccentureMark';
import { ChatInput } from './ChatInput';
import { SuggestedPrompts } from './SuggestedPrompts';

interface WelcomeScreenProps {
  onSubmit: (message: string) => void;
  isLoading?: boolean;
}

export function WelcomeScreen({ onSubmit, isLoading }: WelcomeScreenProps) {
  const appName = process.env.NEXT_PUBLIC_APP_NAME ?? 'Knowledge Assistant';
  return (
    <div className="flex flex-col items-center justify-center h-full bg-black gap-6 px-4">
      <AccentureMark size={48} />
      <h2 className="text-white text-2xl font-semibold">{appName}</h2>
      <p className="text-[#888888] text-sm">Powered by Accenture &amp; Amazon Bedrock</p>
      <ChatInput onSubmit={onSubmit} className="max-w-2xl w-full" isLoading={isLoading} />
      <SuggestedPrompts onSelect={onSubmit} />
    </div>
  );
}
