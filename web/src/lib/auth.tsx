import { createContext, type ReactNode, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { api, setUnauthorizedHandler, tokenStore } from './api';
import type { Me, User } from './types';

type Session = { accessToken: string; user: User };
type AuthContextValue = {
  me: Me | undefined;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (input: { academyName: string; name: string; email: string; password: string }) => Promise<void>;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [token, setToken] = useState(tokenStore.get);

  const applyToken = useCallback(
    (next: string | null) => {
      tokenStore.set(next);
      setToken(next);
      queryClient.clear();
    },
    [queryClient],
  );

  useEffect(() => setUnauthorizedHandler(() => applyToken(null)), [applyToken]);

  const meQuery = useQuery({ queryKey: ['me', token], queryFn: () => api<Me>('/auth/me'), enabled: !!token });

  const value = useMemo<AuthContextValue>(
    () => ({
      me: meQuery.data,
      isAuthenticated: !!token,
      isLoading: !!token && meQuery.isLoading,
      login: async (email, password) => {
        const session = await api<Session>('/auth/login', { body: { email, password } });
        applyToken(session.accessToken);
      },
      register: async (input) => {
        const session = await api<Session>('/auth/register', { body: input });
        applyToken(session.accessToken);
      },
      logout: () => applyToken(null),
    }),
    [token, meQuery.data, meQuery.isLoading, applyToken],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth precisa estar dentro de <AuthProvider>');
  return ctx;
}
