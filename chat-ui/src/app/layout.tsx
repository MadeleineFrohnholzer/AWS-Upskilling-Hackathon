import type { Metadata } from 'next';
import './globals.css';
import { Providers } from '@/components/providers';
import { Toaster } from '@/components/ui/sonner';
import { AppSidebar } from '@/components/layout/AppSidebar';

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
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className="bg-black text-white antialiased">
        <Providers>
          <div className="flex min-h-screen">
            <AppSidebar />
            <main className="ml-64 flex-1 flex flex-col min-h-screen">
              {children}
            </main>
          </div>
          <Toaster />
        </Providers>
      </body>
    </html>
  );
}
