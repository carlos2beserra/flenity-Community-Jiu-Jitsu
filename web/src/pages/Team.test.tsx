import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../lib/auth';
import { tokenStore } from '../lib/api';
import { TeamPage } from './Team';

function response(data: unknown) {
  return new Response(JSON.stringify({ success: true, data, error: null }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function renderTeam() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  tokenStore.set('test-token');
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <AuthProvider>
          <TeamPage />
        </AuthProvider>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

afterEach(() => {
  cleanup();
  tokenStore.set(null);
  vi.unstubAllGlobals();
});

describe('TeamPage', () => {
  it('allows an admin to create and list instructor accounts', async () => {
    const calls: { url: string; method: string; body: Record<string, unknown> | null }[] = [];
    const users: Record<string, unknown>[] = [];
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = new URL(String(input), 'http://localhost');
      const method = init?.method ?? 'GET';
      const body = init?.body ? JSON.parse(String(init.body)) as Record<string, unknown> : null;
      calls.push({ url: `${url.pathname}${url.search}`, method, body });

      if (url.pathname === '/api/auth/me') {
        return response({
          id: 'admin-1',
          name: 'Ana Admin',
          email: 'ana@example.com',
          role: 'ADMIN',
          academy: { id: 'academy-1', name: 'Flenity', blockOverdueDays: 10 },
        });
      }
      if (url.pathname === '/api/users' && method === 'POST') {
        const created = { id: 'instructor-1', ...body };
        users.push(created);
        return response(created);
      }
      if (url.pathname === '/api/users') return response(users);
      throw new Error(`Unexpected request: ${method} ${url.pathname}`);
    }));

    renderTeam();
    await screen.findByText('Nenhum professor cadastrado');
    fireEvent.click(screen.getByRole('button', { name: '+ Adicionar professor' }));
    fireEvent.change(screen.getByLabelText('Nome completo'), { target: { value: 'Carlos Professor' } });
    fireEvent.change(screen.getByLabelText('E-mail de acesso'), { target: { value: 'carlos@example.com' } });
    fireEvent.change(screen.getByLabelText('Senha inicial'), { target: { value: 'senha-segura' } });
    fireEvent.click(screen.getByRole('button', { name: 'Criar acesso' }));

    expect(await screen.findByText(/Acesso de Carlos Professor criado/)).toBeTruthy();
    expect(await screen.findByText('carlos@example.com')).toBeTruthy();
    await waitFor(() => expect(calls.some((call) =>
      call.url === '/api/users' &&
      call.method === 'POST' &&
      call.body?.name === 'Carlos Professor' &&
      call.body?.email === 'carlos@example.com' &&
      call.body?.password === 'senha-segura' &&
      call.body?.role === 'INSTRUCTOR',
    )).toBe(true));
  });

  it('does not expose instructor management to non-admin staff', async () => {
    const requestedUsers = vi.fn();
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      const url = new URL(String(input), 'http://localhost');
      if (url.pathname === '/api/auth/me') {
        return response({
          id: 'instructor-1',
          name: 'Carlos',
          email: 'carlos@example.com',
          role: 'INSTRUCTOR',
          academy: { id: 'academy-1', name: 'Flenity', blockOverdueDays: 10 },
        });
      }
      if (url.pathname === '/api/users') requestedUsers();
      throw new Error(`Unexpected request: ${url.pathname}`);
    }));

    renderTeam();
    expect(await screen.findByText('Somente administradores podem gerenciar a equipe.')).toBeTruthy();
    expect(screen.queryByRole('button', { name: '+ Adicionar professor' })).toBeNull();
    expect(requestedUsers).not.toHaveBeenCalled();
  });
});
