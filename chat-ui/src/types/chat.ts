export type Role = 'user' | 'assistant';
export interface Citation { source: string; page?: number; excerpt?: string; }
export interface Message { id: string; role: Role; content: string; citations: Citation[]; }
export interface Session { sessionId: string; title: string; lastMessageAt: string; }
