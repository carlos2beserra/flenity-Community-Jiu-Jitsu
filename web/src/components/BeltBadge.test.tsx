import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { BeltBadge, isDark } from './BeltBadge';

describe('BeltBadge', () => {
  it('desenha uma listra por grau e mostra o rótulo', () => {
    const { container } = render(<BeltBadge name="Azul" color="#1e5bd6" degree={3} maxDegrees={4} />);
    expect(container.querySelectorAll('.belt-stripe')).toHaveLength(3);
    expect(screen.getByText('Azul')).toBeInTheDocument();
    expect(screen.getByText(/3º grau/)).toBeInTheDocument();
  });

  it('chama a faixa sem graus de "Lisa"', () => {
    render(<BeltBadge name="Branca" color="#f5f5f5" degree={0} />);
    expect(screen.getByText('Lisa')).toBeInTheDocument();
  });

  it('detecta faixa escura para usar ponteira vermelha (faixa preta)', () => {
    expect(isDark('#111111')).toBe(true);
    expect(isDark('#f5f5f5')).toBe(false);
  });
});
