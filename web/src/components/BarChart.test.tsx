import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { BarChart, niceMax } from './BarChart';

describe('BarChart', () => {
  it('mostra tooltip ao passar o mouse na barra', () => {
    const { container } = render(
      <BarChart ariaLabel="teste" data={[{ label: 'Seg', value: 10, tooltip: '10 check-ins' }, { label: 'Ter', value: 4, tooltip: '4 check-ins' }]} />,
    );
    fireEvent.mouseEnter(container.querySelectorAll('.hit')[1]);
    expect(container.querySelector('.tooltip')).toHaveTextContent('Ter · 4 check-ins');
    expect(screen.getByRole('img', { name: 'teste' })).toBeInTheDocument();
  });

  it('arredonda o topo do eixo para um valor redondo', () => {
    expect(niceMax(37)).toBe(50);
    expect(niceMax(8)).toBe(10);
    expect(niceMax(120)).toBe(200);
  });
});
