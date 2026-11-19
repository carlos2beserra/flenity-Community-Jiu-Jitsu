/** Faixa desenhada: cor da faixa, ponteira preta e listras brancas por grau (como no BJJ). */
export function BeltBadge({ name, color, degree, maxDegrees, showLabel = true }: {
  name: string; color: string; degree: number; maxDegrees?: number; showLabel?: boolean;
}) {
  const tipColor = isDark(color) ? '#c8361a' : '#111';
  return (
    <span className="belt" title={`${name} · ${degree} grau(s)`}>
      <span className="belt-bar" style={{ background: color }} aria-hidden>
        <span className="belt-tip" style={{ background: tipColor }}>
          {Array.from({ length: degree }, (_, i) => <span key={i} className="belt-stripe" />)}
        </span>
      </span>
      {showLabel && (
        <span className="belt-name">
          {name}
          <small>{degree === 0 ? 'Lisa' : `${degree}º grau`}{maxDegrees !== undefined && ` / ${maxDegrees}`}</small>
        </span>
      )}
    </span>
  );
}

export function isDark(hex: string): boolean {
  const value = hex.replace('#', '');
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(value.slice(i, i + 2), 16));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b < 60;
}
