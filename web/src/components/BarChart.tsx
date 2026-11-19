import { useEffect, useRef, useState } from 'react';

type Datum = { label: string; value: number; tooltip: string };

/**
 * Gráfico de barras de série única: barras finas com topo arredondado ancoradas na base,
 * grade recessiva e tooltip por barra (área de hover maior que a barra).
 */
export function BarChart({ data, height = 180, formatAxis = String, ariaLabel }: {
  data: Datum[]; height?: number; formatAxis?: (value: number) => string; ariaLabel: string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const [width, chartRef] = useMeasuredWidth();
  const pad = { top: 10, right: 4, bottom: 22, left: 44 };
  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;
  const max = niceMax(Math.max(1, ...data.map((d) => d.value)));
  const step = innerW / Math.max(1, data.length);
  const barW = Math.min(36, step * 0.55);
  const ticks = [0, max / 2, max];
  const y = (v: number) => pad.top + innerH - (v / max) * innerH;

  return (
    <div className="chart" ref={chartRef}>
      <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label={ariaLabel}>
        {ticks.map((t) => (
          <g key={t}>
            <line className="grid-line" x1={pad.left} x2={width - pad.right} y1={y(t)} y2={y(t)} />
            <text className="axis" x={pad.left - 8} y={y(t) + 3} textAnchor="end">{formatAxis(t)}</text>
          </g>
        ))}
        {data.map((d, i) => {
          const cx = pad.left + step * i + step / 2;
          const h = Math.max(d.value > 0 ? 2 : 0, (d.value / max) * innerH);
          return (
            <g key={d.label}>
              <path className={`bar${hover !== null && hover !== i ? ' dim' : ''}`} d={roundedTop(cx - barW / 2, pad.top + innerH - h, barW, h, 4)} />
              <text className="axis" x={cx} y={height - 6} textAnchor="middle">{d.label}</text>
              <rect className="hit" x={cx - step / 2} y={pad.top} width={step} height={innerH}
                onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)} />
            </g>
          );
        })}
      </svg>
      {hover !== null && (
        <div className="tooltip" style={{
          left: `${((pad.left + step * hover + step / 2) / width) * 100}%`,
          top: `${(y(data[hover].value) / height) * 100}%`,
        }}>
          {data[hover].label} · <b>{data[hover].tooltip}</b>
        </div>
      )}
      <table className="sr-only" style={{ position: 'absolute', width: 1, height: 1, overflow: 'hidden', clip: 'rect(0 0 0 0)' }}>
        <tbody>{data.map((d) => <tr key={d.label}><td>{d.label}</td><td>{d.tooltip}</td></tr>)}</tbody>
      </table>
    </div>
  );
}

/** Mede a largura do container para o SVG renderizar em escala 1:1 (texto legível em qualquer card). */
function useMeasuredWidth() {
  const ref = useRef<HTMLDivElement>(null);
  const [value, setValue] = useState(600);
  useEffect(() => {
    const el = ref.current;
    if (!el || typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver(([entry]) => setValue(Math.max(200, Math.round(entry.contentRect.width))));
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  return [value, ref] as const;
}

function roundedTop(x: number, y: number, w: number, h: number, r: number) {
  if (h <= 0) return '';
  const rr = Math.min(r, h, w / 2);
  return `M${x},${y + h} V${y + rr} Q${x},${y} ${x + rr},${y} H${x + w - rr} Q${x + w},${y} ${x + w},${y + rr} V${y + h} Z`;
}

export function niceMax(value: number) {
  const magnitude = 10 ** Math.floor(Math.log10(value));
  const normalized = value / magnitude;
  const nice = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return nice * magnitude;
}
