import ReactMarkdown from 'react-markdown';
import rehypeHighlight from 'rehype-highlight';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { AccentureMark } from '@/components/brand/AccentureMark';
import { CitationList } from './CitationList';
import { CodeBlock } from './CodeBlock';
import type { Message } from '@/types/chat';
import 'highlight.js/styles/github.css';

interface MessageBubbleProps {
  message: Message;
  userEmail?: string;
}

function getInitials(email?: string): string {
  if (!email) return 'U';
  const parts = email.split('@')[0].split(/[._-]/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return email.slice(0, 2).toUpperCase();
}

export function MessageBubble({ message, userEmail }: MessageBubbleProps) {
  if (message.role === 'user') {
    return (
      <div className="flex justify-end gap-3 py-2">
        <div className="bg-muted border-l-2 border-[#A100FF] rounded-2xl px-4 py-2 text-foreground max-w-2xl">
          <p className="whitespace-pre-wrap">{message.content}</p>
        </div>
        <Avatar className="w-8 h-8 flex-shrink-0">
          <AvatarFallback className="bg-[#A100FF] text-white text-xs">
            {getInitials(userEmail)}
          </AvatarFallback>
        </Avatar>
      </div>
    );
  }

  return (
    <div className="flex gap-3 py-2">
      <div className="flex-shrink-0 mt-1">
        <AccentureMark size={20} />
      </div>
      <div className="flex-1 max-w-2xl">
        <div className="text-foreground prose dark:prose-invert max-w-none">
          <ReactMarkdown
            rehypePlugins={[rehypeHighlight]}
            components={{
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              code: CodeBlock as any,
            }}
          >
            {message.content}
          </ReactMarkdown>
        </div>
        {message.citations.length > 0 && (
          <CitationList citations={message.citations} />
        )}
      </div>
    </div>
  );
}
