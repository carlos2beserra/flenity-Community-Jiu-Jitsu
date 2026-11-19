import { type FormEvent, type ReactNode, useEffect } from 'react';
import { ApiError } from '../lib/api';
import { initials } from '../lib/format';

export function PageHeader({ kicker, title, actions }: { kicker?: ReactNode; title: string; actions?: ReactNode }) {
  return (
    <header className="page-head">
      <div>
        {kicker && <div className="kicker">{kicker}</div>}
        <h1>{title}</h1>
      </div>
      {actions && <div className="actions">{actions}</div>}
    </header>
  );
}

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={title}>
        <h2>{title}</h2>
        {children}
      </div>
    </div>
  );
}

/** Formulário de modal com submit, botão cancelar e exibição de erro da API. */
export function ModalForm({
  title, onClose, onSubmit, submitLabel = 'Salvar', pending, error, children,
}: {
  title: string; onClose: () => void; onSubmit: () => void; submitLabel?: string;
  pending?: boolean; error?: unknown; children: ReactNode;
}) {
  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    onSubmit();
  };
  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={handleSubmit}>
        <div className="form-grid">{children}</div>
        {error != null && <div className="alert alert-bad" style={{ marginTop: 16 }}>{errorMessage(error)}</div>}
        <div className="modal-foot">
          <button type="button" className="btn btn-ghost" onClick={onClose}>Cancelar</button>
          <button type="submit" className="btn btn-primary" disabled={pending}>{pending ? 'Salvando…' : submitLabel}</button>
        </div>
      </form>
    </Modal>
  );
}

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    const details = Array.isArray(error.body.details) ? `: ${error.body.details.join('; ')}` : '';
    return `${error.message}${details}`;
  }
  return error instanceof Error ? error.message : 'Erro inesperado';
}

export function Field({ label, children, span }: { label: string; children: ReactNode; span?: boolean }) {
  return (
    <label className={`field${span ? ' span-2' : ''}`}>
      <span>{label}</span>
      {children}
    </label>
  );
}

type Tone = 'good' | 'warn' | 'bad' | 'neutral';
export function Badge({ tone, children }: { tone: Tone; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

export function Stat({ label, value, sub, hot }: { label: string; value: ReactNode; sub?: ReactNode; hot?: boolean }) {
  return (
    <div className={`card stat${hot ? ' hot' : ''}`}>
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
      {sub && <div className="stat-sub">{sub}</div>}
    </div>
  );
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <strong>{title}</strong>
      {children}
    </div>
  );
}

export function Person({ name, sub }: { name: string; sub?: ReactNode }) {
  return (
    <span className="person">
      <span className="avatar" aria-hidden>{initials(name)}</span>
      <span>
        <span style={{ fontWeight: 600 }}>{name}</span>
        {sub && <span className="muted" style={{ display: 'block', fontSize: 12 }}>{sub}</span>}
      </span>
    </span>
  );
}

export function Pager({ page, pageSize, total, onPage }: { page: number; pageSize: number; total: number; onPage: (page: number) => void }) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  return (
    <div className="pager">
      <span>{total} registro(s) · página {page} de {pages}</span>
      <div>
        <button className="btn btn-sm" disabled={page <= 1} onClick={() => onPage(page - 1)}>Anterior</button>
        <button className="btn btn-sm" disabled={page >= pages} onClick={() => onPage(page + 1)}>Próxima</button>
      </div>
    </div>
  );
}

export function Loading() {
  return <div className="empty">Carregando…</div>;
}
