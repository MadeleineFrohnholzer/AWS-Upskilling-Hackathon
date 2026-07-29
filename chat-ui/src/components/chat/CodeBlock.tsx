'use client';

import { CopyButton } from './CopyButton';

interface CodeBlockProps {
  inline?: boolean;
  className?: string;
  children?: React.ReactNode;
}

export function CodeBlock({ inline, className, children }: CodeBlockProps) {
  const code = String(children ?? '').replace(/\n$/, '');

  if (inline) {
    return (
      <code className="bg-[#1A1A1A] px-1 rounded text-[#A100FF] font-mono text-sm">
        {children}
      </code>
    );
  }

  return (
    <div className="relative group my-2">
      <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
        <CopyButton text={code} />
      </div>
      <pre className={`bg-[#0D0D0D] rounded-xl p-4 overflow-x-auto font-mono text-sm text-white ${className ?? ''}`}>
        <code>{children}</code>
      </pre>
    </div>
  );
}
