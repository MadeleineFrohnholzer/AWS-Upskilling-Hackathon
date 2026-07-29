'use client';

import { useSidebar } from '@/components/providers/SidebarProvider';

export function SidebarLayout({ children }: { children: React.ReactNode }) {
  const { collapsed } = useSidebar();
  return (
    <main
      className={`flex-1 flex flex-col min-h-screen transition-all duration-300 ${
        collapsed ? 'md:ml-16' : 'md:ml-64'
      }`}
    >
      {children}
    </main>
  );
}
