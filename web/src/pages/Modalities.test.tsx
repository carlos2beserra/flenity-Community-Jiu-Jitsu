import { cleanup, render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ModalitiesPage } from './Modalities';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('Jiu-Jitsu page', () => {
  it('shows the Jiu-Jitsu belt editor without offering other modalities', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(JSON.stringify({
        success: true,
        data: [{
          id: 'bjj',
          name: 'Jiu-Jitsu',
          belts: [{
            id: 'white',
            name: 'Branca',
            color: '#f5f5f5',
            order: 0,
            minClasses: 40,
            maxDegrees: 4,
          }],
        }],
        error: null,
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })),
    );
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });

    render(
      <QueryClientProvider client={queryClient}>
        <ModalitiesPage />
      </QueryClientProvider>,
    );

    expect(await screen.findByText('Branca')).toBeTruthy();
    expect(screen.queryByText('Nova modalidade')).toBeNull();
  });
});
