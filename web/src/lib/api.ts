export type ApiErrorBody = { code: string; message: string; details?: unknown };
type Envelope<T> = { success: boolean; data: T; error: ApiErrorBody | null };

export class ApiError extends Error {
  readonly status: number;
  readonly body: ApiErrorBody;

  constructor(status: number, body: ApiErrorBody) {
    super(body.message);
    this.status = status;
    this.body = body;
  }
}

const TOKEN_KEY = 'flenity.token';

export const tokenStore = {
  get: (): string | null => {
    try {
      return localStorage.getItem(TOKEN_KEY);
    } catch {
      return null;
    }
  },
  set: (token: string | null) => {
    try {
      if (token) localStorage.setItem(TOKEN_KEY, token);
      else localStorage.removeItem(TOKEN_KEY);
    } catch {
      /* storage indisponível: sessão vale apenas em memória */
    }
  },
};

let onUnauthorized: () => void = () => {};
export const setUnauthorizedHandler = (handler: () => void) => {
  onUnauthorized = handler;
};

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = tokenStore.get();
  const response = await fetch(`/api${path}`, {
    method: init.method ?? (init.body ? 'POST' : 'GET'),
    headers: {
      ...(init.body !== undefined && { 'Content-Type': 'application/json' }),
      ...(token && { Authorization: `Bearer ${token}` }),
    },
    body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
  });

  const envelope = (await response.json().catch(() => null)) as Envelope<T> | null;
  if (!response.ok || !envelope?.success) {
    if (response.status === 401 && token) onUnauthorized();
    throw new ApiError(response.status, envelope?.error ?? { code: 'NETWORK', message: 'Falha de comunicação com o servidor' });
  }
  return envelope.data;
}

export type Paginated<T> = { items: T[]; total: number; page: number; pageSize: number };

export function toQuery(params: Record<string, string | number | boolean | undefined | null>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '') search.set(key, String(value));
  }
  const query = search.toString();
  return query ? `?${query}` : '';
}
