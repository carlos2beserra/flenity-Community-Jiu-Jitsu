import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { StudentForm } from './Students';

function response(data: unknown) {
  return new Response(JSON.stringify({ success: true, data, error: null }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function renderForm() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <StudentForm onClose={() => {}} />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('StudentForm', () => {
  it('registers a student using a Jiu-Jitsu plan', async () => {
    let registration: Record<string, unknown> | null = null;
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = new URL(String(input), 'http://localhost');
      if (url.pathname === '/api/plans') {
        return response([
          {
            id: 'plan-bjj',
            name: 'Jiu-Jitsu mensal',
            priceCents: 5000,
            billingCycleMonths: 1,
            active: true,
            modalities: [{ modality: { id: 'bjj', name: 'Jiu-Jitsu' } }],
          },
        ]);
      }
      if (url.pathname === '/api/students/registration' && init?.method === 'POST') {
        registration = JSON.parse(String(init.body)) as Record<string, unknown>;
        return response({ id: 'student-1', name: 'Ana Silva' });
      }
      throw new Error(`Unexpected request: ${init?.method ?? 'GET'} ${url.pathname}`);
    }));

    renderForm();
    fireEvent.change(await screen.findByLabelText('Nome completo'), {
      target: { value: 'Ana Silva' },
    });
    fireEvent.click(screen.getByLabelText('Selecionar plano Jiu-Jitsu mensal'));
    expect(screen.getAllByText('Jiu-Jitsu').length).toBeGreaterThan(0);
    fireEvent.click(screen.getByRole('button', { name: 'Cadastrar e matricular' }));

    await waitFor(() => expect(registration).not.toBeNull());
    expect(registration).toEqual(expect.objectContaining({
      name: 'Ana Silva',
      memberships: [
        expect.objectContaining({ planId: 'plan-bjj' }),
      ],
    }));
  });
});
