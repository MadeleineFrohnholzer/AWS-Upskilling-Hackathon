import type { Metadata } from 'next';
import './globals.css';
import { Providers } from '@/components/providers';
import { Toaster } from '@/components/ui/sonner';
import { AppSidebar } from '@/components/layout/AppSidebar';
import { SidebarLayout } from '@/components/layout/SidebarLayout';

export const metadata: Metadata = {
  title: process.env.NEXT_PUBLIC_APP_NAME ?? 'Knowledge Assistant',
  description: 'Powered by Accenture & Amazon Bedrock',
  icons: { icon: '/favicon.svg' },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="bg-background text-foreground antialiased">
        <Providers>
          <div className="flex min-h-screen">
            <AppSidebar />
            <SidebarLayout>
              {children}
            </SidebarLayout>
          </div>
          <Toaster />
        </Providers>
      </body>
    </html>
  );
}
