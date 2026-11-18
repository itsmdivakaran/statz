/** StatNext mark: a distribution curve rising into a forward arrow, on the brand gradient. */
export function Logo({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <defs>
        <linearGradient id="sn-g" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#10B981" />
          <stop offset="0.55" stopColor="#2563EB" />
          <stop offset="1" stopColor="#EC4899" />
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx="15" fill="url(#sn-g)" />
      <path d="M10 46 C20 46 21 20 30 20 C38 20 38 38 46 38 C49 38 51 34 53 30" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M45 28 L54 28 L54 37" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M10 46 C20 46 21 20 30 20 C38 20 38 38 46 38 L46 46 Z" fill="#fff" opacity="0.18" />
    </svg>
  );
}

export function Wordmark() {
  return (
    <span className="flex items-center gap-2">
      <Logo size={26} />
      <span className="text-[15px] font-bold tracking-tight">Stat<span className="bg-gradient-to-r from-accent to-pink bg-clip-text text-transparent">Next</span></span>
    </span>
  );
}
