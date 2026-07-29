'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  PlusIcon,
  SearchIcon,
  UploadIcon,
  MenuIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { AccentureMark } from '@/components/brand/AccentureMark';
import { ChatHistoryList } from './ChatHistoryList';
import { UserIdentity } from './UserIdentity';
import { UploadSheet } from '@/components/upload/UploadSheet';
import { Sheet, SheetContent } from '@/components/ui/sheet';
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { useSidebar } from '@/components/providers/SidebarProvider';

function NavButton({
  icon,
  label,
  collapsed,
  onClick,
}: {
  icon: React.ReactNode;
  label: string;
  collapsed: boolean;
  onClick: () => void;
}) {
  const btn = (
    <Button
      variant="ghost"
      className={`w-full text-muted-foreground hover:text-[#A100FF] hover:bg-muted ${
        collapsed ? 'justify-center px-0' : 'justify-start'
      }`}
      onClick={onClick}
    >
      {icon}
      {!collapsed && <span className="ml-2">{label}</span>}
    </Button>
  );

  if (!collapsed) return btn;

  return (
    <Tooltip>
      <TooltipTrigger asChild>{btn}</TooltipTrigger>
      <TooltipContent side="right">{label}</TooltipContent>
    </Tooltip>
  );
}

function SidebarContent({
  onNewChat,
  onSearch,
  onUpload,
  collapsed,
  onToggle,
}: {
  onNewChat: () => void;
  onSearch: () => void;
  onUpload: () => void;
  collapsed: boolean;
  onToggle: () => void;
}) {
  return (
    <TooltipProvider delayDuration={200}>
      <div className="flex flex-col h-full bg-background">
        {/* Header — h-12 matches TopBar height */}
        <div
          className={`flex items-center h-12 px-4 border-b border-border flex-shrink-0 ${
            collapsed ? 'justify-center' : 'justify-between'
          }`}
        >
          {!collapsed && (
            <div className="flex items-center gap-2">
              <AccentureMark size={24} />
              <span className="text-foreground font-semibold text-sm tracking-tight">accenture</span>
            </div>
          )}
          {collapsed && <AccentureMark size={24} />}

          {/* Collapse toggle — only visible on desktop */}
          {!collapsed && (
            <Button
              variant="ghost"
              size="icon"
              className="hidden md:flex h-6 w-6 text-muted-foreground hover:text-[#A100FF] hover:bg-transparent flex-shrink-0"
              onClick={onToggle}
              aria-label="Collapse sidebar"
            >
              <ChevronLeftIcon className="h-4 w-4" />
            </Button>
          )}
        </div>

        {/* Nav */}
        <nav className={`flex flex-col gap-1 p-2 mt-2 ${collapsed ? 'items-center' : ''}`}>
          <NavButton
            icon={<PlusIcon className="h-4 w-4 flex-shrink-0" />}
            label="New Chat"
            collapsed={collapsed}
            onClick={onNewChat}
          />
          <NavButton
            icon={<SearchIcon className="h-4 w-4 flex-shrink-0" />}
            label="Search"
            collapsed={collapsed}
            onClick={onSearch}
          />
          <NavButton
            icon={<UploadIcon className="h-4 w-4 flex-shrink-0" />}
            label="Upload Document"
            collapsed={collapsed}
            onClick={onUpload}
          />
        </nav>

        {/* Chat history — hidden when collapsed */}
        {!collapsed && (
          <div className="flex-1 overflow-hidden">
            <ChatHistoryList />
          </div>
        )}
        {collapsed && <div className="flex-1" />}

        {/* Footer */}
        <div
          className={`mt-auto border-t border-border ${
            collapsed ? 'flex flex-col items-center gap-2 py-3' : 'p-3'
          }`}
        >
          {collapsed ? (
            <>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-8 w-8 text-muted-foreground hover:text-[#A100FF] hover:bg-transparent"
                    onClick={onToggle}
                    aria-label="Expand sidebar"
                  >
                    <ChevronRightIcon className="h-4 w-4" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent side="right">Expand sidebar</TooltipContent>
              </Tooltip>
            </>
          ) : (
            <UserIdentity />
          )}
        </div>
      </div>
    </TooltipProvider>
  );
}

export function AppSidebar() {
  const router = useRouter();
  const { collapsed, toggle } = useSidebar();
  const [uploadOpen, setUploadOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleNewChat = () => { router.push('/'); setMobileOpen(false); };
  const handleSearch = () => { setSearchOpen(true); setMobileOpen(false); };
  const handleUpload = () => { setUploadOpen(true); setMobileOpen(false); };

  return (
    <>
      {/* Mobile hamburger */}
      <Button
        variant="ghost"
        size="icon"
        className="md:hidden fixed top-2.5 left-3 z-20 text-muted-foreground hover:text-[#A100FF] hover:bg-transparent"
        onClick={() => setMobileOpen(true)}
        aria-label="Open menu"
      >
        <MenuIcon className="h-5 w-5" />
      </Button>

      {/* Desktop sidebar */}
      <aside
        className={`hidden md:flex md:flex-col bg-background border-r border-border h-screen fixed left-0 top-0 z-10 transition-all duration-300 overflow-hidden ${
          collapsed ? 'w-16' : 'w-64'
        }`}
      >
        <SidebarContent
          onNewChat={handleNewChat}
          onSearch={handleSearch}
          onUpload={handleUpload}
          collapsed={collapsed}
          onToggle={toggle}
        />
      </aside>

      {/* Mobile sidebar Sheet (always full width) */}
      <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
        <SheetContent side="left" className="w-64 p-0 bg-background border-r border-border">
          <SidebarContent
            onNewChat={handleNewChat}
            onSearch={handleSearch}
            onUpload={handleUpload}
            collapsed={false}
            onToggle={() => {}}
          />
        </SheetContent>
      </Sheet>

      <UploadSheet open={uploadOpen} onOpenChange={setUploadOpen} />

      <CommandDialog open={searchOpen} onOpenChange={setSearchOpen}>
        <CommandInput placeholder="Search conversations…" />
        <CommandList>
          <CommandEmpty>No results found.</CommandEmpty>
          <CommandGroup heading="Recent Chats">
            <CommandItem>No recent chats</CommandItem>
          </CommandGroup>
        </CommandList>
      </CommandDialog>
    </>
  );
}
