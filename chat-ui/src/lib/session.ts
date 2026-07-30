const SESSION_KEY = 'chatSessionId';

export function getOrCreateSessionId(): string | null {
  if (typeof window === 'undefined') return null;
  const existing = localStorage.getItem(SESSION_KEY);
  if (existing) return existing;
  const newId = crypto.randomUUID();
  localStorage.setItem(SESSION_KEY, newId);
  return newId;
}
