import { type FormEvent, useState } from 'react';
import { useAuth } from '../lib/auth';
import { errorMessage, Field } from '../components/ui';

export function LoginPage() {
  const { login, register } = useAuth();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [form, setForm] = useState({ academyName: '', name: '', email: '', password: '' });
  const [error, setError] = useState<unknown>(null);
  const [pending, setPending] = useState(false);
  const set = (key: keyof typeof form) => (e: { target: { value: string } }) => setForm({ ...form, [key]: e.target.value });

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setPending(true);
    setError(null);
    try {
      if (mode === 'login') await login(form.email, form.password);
      else await register(form);
    } catch (err) {
      setError(err);
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="auth">
      <section className="auth-poster">
        <div className="auth-orbit" aria-hidden="true">
          <span className="auth-orbit-ring" />
          <span className="auth-orbit-center">F</span>
          <span className="auth-orbit-dot" />
        </div>
        <div>
          <h1>Flenity</h1>
          <p className="auth-tagline">Jiu-Jitsu Community</p>
          <p>Gestão completa para sua academia de Jiu-Jitsu: alunos, aulas, graduações e planos em uma só plataforma.</p>
        </div>
        <div className="auth-pillars">
          <span>Jiu-Jitsu</span><span>Graduação</span><span>Comunidade</span>
        </div>
      </section>
      <section className="auth-form">
        <form onSubmit={handleSubmit}>
          <h2>{mode === 'login' ? 'Acessar gestão' : 'Criar academia'}</h2>
          {mode === 'register' && (
            <>
              <Field label="Nome do espaço"><input className="input" required value={form.academyName} onChange={set('academyName')} /></Field>
              <Field label="Seu nome"><input className="input" required value={form.name} onChange={set('name')} /></Field>
            </>
          )}
          <Field label="E-mail"><input className="input" type="email" required autoComplete="email" value={form.email} onChange={set('email')} /></Field>
          <Field label="Senha">
            <input className="input" type="password" required minLength={mode === 'register' ? 8 : 1}
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'} value={form.password} onChange={set('password')} />
          </Field>
          {error != null && <div className="alert alert-bad">{errorMessage(error)}</div>}
          <button className="btn btn-primary" disabled={pending} style={{ padding: '11px 14px' }}>
            {pending ? 'Aguarde…' : mode === 'login' ? 'Entrar' : 'Criar conta'}
          </button>
          <span className="muted">
            {mode === 'login' ? 'Novo espaço? ' : 'Já tem conta? '}
            <button type="button" className="link-btn" onClick={() => setMode(mode === 'login' ? 'register' : 'login')}>
              {mode === 'login' ? 'Cadastre-se' : 'Entrar'}
            </button>
          </span>
        </form>
      </section>
    </div>
  );
}
