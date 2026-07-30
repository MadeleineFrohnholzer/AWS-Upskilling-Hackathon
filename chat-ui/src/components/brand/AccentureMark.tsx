export function AccentureMark({ size = 24 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden>
      <path d="M6 4l12 8-12 8" stroke="#A100FF" strokeWidth="3"
            strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
