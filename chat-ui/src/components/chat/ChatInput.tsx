'use client';

import { useRef, useState, useEffect, KeyboardEvent } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { ArrowUp, Loader2, Plus, Sparkles } from 'lucide-react';
import { cn } from '@/lib/utils';

interface ChatInputProps {
  onSubmit: (message: string) => void;
  isLoading?: boolean;
  className?: string;
  defaultValue?: string;
  value?: string;
  onChange?: (value: string) => void;
}

export function ChatInput({ onSubmit, isLoading, className, defaultValue, value: externalValue, onChange: externalOnChange }: ChatInputProps) {
  const isControlled = externalValue !== undefined;
  const [internalValue, setInternalValue] = useState(defaultValue ?? '');
  const value = isControlled ? externalValue! : internalValue;
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const setValue = (v: string) => {
    if (!isControlled) setInternalValue(v);
    externalOnChange?.(v);
  };

  useEffect(() => {
    if (isControlled && externalValue && textareaRef.current) {
      textareaRef.current.focus();
      const len = externalValue.length;
      textareaRef.current.setSelectionRange(len, len);
    }
  }, [isControlled, externalValue]);

  const handleSubmit = () => {
    const trimmed = value.trim();
    if (!trimmed || isLoading) return;
    onSubmit(trimmed);
    setValue('');
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const handleInput = () => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 144)}px`;
  };

  return (
    <div
      className={cn(
        'bg-card border border-border rounded-xl focus-within:border-[#A100FF] transition-colors',
        className
      )}
    >
      <Textarea
        ref={textareaRef}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={handleKeyDown}
        onInput={handleInput}
        placeholder="Ask anything about your documents…"
        className="bg-transparent border-none resize-none text-foreground placeholder:text-muted-foreground focus:ring-0 focus-visible:ring-0 focus-visible:ring-offset-0 min-h-[48px] max-h-[144px] py-3 px-4"
        disabled={isLoading}
      />
      <div className="flex items-center justify-between px-3 pb-2">
        <div className="flex gap-1">
          <Button variant="ghost" size="icon" className="h-7 w-7 text-muted-foreground hover:text-foreground">
            <Plus className="h-4 w-4" />
          </Button>
          <Button variant="ghost" size="icon" className="h-7 w-7 text-muted-foreground hover:text-foreground">
            <Sparkles className="h-4 w-4" />
          </Button>
        </div>
        <Button
          size="icon"
          className="h-7 w-7 bg-[#A100FF] hover:bg-[#8A00E0] text-white disabled:opacity-40"
          onClick={handleSubmit}
          disabled={isLoading || !value.trim()}
        >
          {isLoading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <ArrowUp className="h-4 w-4" />
          )}
        </Button>
      </div>
    </div>
  );
}
