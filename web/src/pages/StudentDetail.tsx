import { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { api } from '../lib/api';
import {
  formatDate, formatDateTime, formatMoney, INVOICE_STATE_LABEL, invoiceState, PAYMENT_LABEL, STUDENT_STATUS,
} from '../lib/format';
import type { Invoice, Rank, StudentDetail } from '../lib/types';
import { BeltBadge } from '../components/BeltBadge';
import { MembershipForm, PayInvoiceModal, useInvalidateFinance } from '../components/forms';
import { Badge, Empty, errorMessage, Loading, Modal, PageHeader } from '../components/ui';
import { STATUS_TONE, StudentForm } from './Students';

export const INVOICE_TONE = { PAID: 'good', CANCELED: 'neutral', OVERDUE: 'bad', PENDING: 'warn' } as const;

export function StudentDetailPage() {
  const { id } = useParams<{ id: string }>();
  const student = useQuery({ queryKey: ['student', id], queryFn: () => api<StudentDetail>(`/students/${id}`) });
  const invalidate = useInvalidateFinance();
  const [editing, setEditing] = useState(false);
  const [enrolling, setEnrolling] = useState(false);
  const [paying, setPaying] = useState<Invoice | null>(null);
  const [credentials, setCredentials] = useState<{ email: string; password: string } | null>(null);
  const [inviteUrl, setInviteUrl] = useState<string | null>(null);
  const [inviteCopied, setInviteCopied] = useState(false);
  const [inviteCopyError, setInviteCopyError] = useState(false);

  const grantAccess = useMutation({
    mutationFn: () => api<{ email: string; password: string }>(`/students/${id}/app-access`, { method: 'POST', body: {} }),
    onSuccess: (data) => { setCredentials(data); invalidate(); },
  });
  const revokeAccess = useMutation({
    mutationFn: () => api(`/students/${id}/app-access`, { method: 'DELETE' }),
    onSuccess: invalidate,
  });
  const communityInvite = useMutation({
    mutationFn: () => api<{ token: string }>(`/students/${id}/community-invite`, { method: 'POST', body: {} }),
    onSuccess: ({ token }) => {
      const url = new URL('/convite', window.location.origin);
      url.hash = new URLSearchParams({ token }).toString();
      setInviteUrl(url.toString());
      setInviteCopied(false);
      setInviteCopyError(false);
    },
  });

  const cancelMembership = useMutation({
    mutationFn: (membershipId: string) => api(`/memberships/${membershipId}/cancel`, { method: 'POST' }),
    onSuccess: invalidate,
  });
  const promote = useMutation({
    mutationFn: (modalityId: string) => api('/graduations/promote', { body: { studentId: id, modalityId } }),
    onSuccess: invalidate,
  });

  if (!student.data) return student.error ? <Empty title="Aluno não encontrado" /> : <Loading />;
  const s = student.data;
  const currentRanks = latestPerModality(s.ranks);

  return (
    <>
      <PageHeader kicker={<Link to="/alunos">← Alunos</Link>} title={s.name}
        actions={<>
          <button className="btn" disabled={communityInvite.isPending || !s.email || s.status !== 'ACTIVE'}
            title={!s.email ? 'Cadastre um e-mail primeiro' : undefined}
            onClick={() => communityInvite.mutate()}>
            {communityInvite.isPending ? 'Gerando convite…' : 'Convidar para comunidade'}
          </button>
          <button className="btn" disabled={grantAccess.isPending} title={s.email ? undefined : 'Cadastre um e-mail primeiro'}
            onClick={() => (!s.hasAppAccess || confirm('Gerar uma nova senha do app para este aluno?')) && grantAccess.mutate()}>
            {s.hasAppAccess ? 'Nova senha do app' : 'Liberar app'}
          </button>
          <button className="btn" onClick={() => setEditing(true)}>Editar</button>
          <button className="btn btn-primary" onClick={() => setEnrolling(true)}>+ Matrícula</button>
        </>} />

      <div className="grid grid-main reveal">
        <div className="grid" style={{ alignContent: 'start' }}>
          <div className="card">
            <h2 className="card-title">Graduação</h2>
            {currentRanks.length === 0 ? <Empty title="Sem graduação">Matricule o aluno em um plano para iniciar a régua.</Empty> : (
              <ul className="timeline">
                {currentRanks.map((r) => (
                  <li key={r.modality.id}>
                    <span><strong>{r.modality.name}</strong><span className="muted" style={{ display: 'block', fontSize: 12 }}>desde {formatDate(r.promotedAt)}</span></span>
                    <span style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
                      <BeltBadge name={r.belt.name} color={r.belt.color} degree={r.degree} maxDegrees={r.belt.maxDegrees} />
                      <button className="btn btn-sm" disabled={promote.isPending}
                        onClick={() => confirm(`Graduar ${s.name} em ${r.modality.name}?`) && promote.mutate(r.modality.id)}>Graduar</button>
                    </span>
                  </li>
                ))}
              </ul>
            )}
            {grantAccess.error && <div className="alert alert-bad" style={{ marginTop: 10 }}>{errorMessage(grantAccess.error)}</div>}
            {promote.error && <div className="alert alert-bad" style={{ marginTop: 10 }}>{errorMessage(promote.error)}</div>}
          </div>

          <div className="card">
            <h2 className="card-title">Mensalidades</h2>
            {s.invoices.length === 0 ? <Empty title="Nenhuma cobrança" /> : (
              <table>
                <thead><tr><th>Vencimento</th><th>Descrição</th><th className="num">Valor</th><th>Status</th><th /></tr></thead>
                <tbody>
                  {s.invoices.map((inv) => {
                    const state = invoiceState(inv);
                    return (
                      <tr key={inv.id}>
                        <td className="mono">{formatDate(inv.dueDate)}</td>
                        <td>{inv.description}</td>
                        <td className="num mono">{formatMoney(inv.amountCents)}</td>
                        <td>
                          <Badge tone={INVOICE_TONE[state]}>{INVOICE_STATE_LABEL[state]}</Badge>
                          {inv.paymentMethod && <span className="muted" style={{ fontSize: 12 }}> · {PAYMENT_LABEL[inv.paymentMethod]}</span>}
                        </td>
                        <td className="actions">
                          {inv.status === 'PENDING' && <button className="btn btn-sm" onClick={() => setPaying(inv)}>Receber</button>}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
        </div>

        <div className="grid" style={{ alignContent: 'start' }}>
          <div className="card">
            <h2 className="card-title">Ficha <Badge tone={STATUS_TONE[s.status]}>{STUDENT_STATUS[s.status]}</Badge></h2>
            <dl className="kv">
              <dt>E-mail</dt><dd>{s.email ?? '—'}</dd>
              <dt>Telefone</dt><dd className="mono">{s.phone ?? '—'}</dd>
              <dt>CPF</dt><dd className="mono">{s.cpf ?? '—'}</dd>
              <dt>Nascimento</dt><dd>{formatDate(s.birthDate)}</dd>
              <dt>Aluno desde</dt><dd>{formatDate(s.createdAt)}</dd>
              <dt>App do aluno</dt>
              <dd>
                {s.hasAppAccess ? <>
                  <Badge tone="good">Liberado</Badge>{' '}
                  <button className="btn btn-sm btn-ghost btn-danger" onClick={() => confirm('Revogar acesso ao app?') && revokeAccess.mutate()}>Revogar</button>
                </> : <Badge tone="neutral">Sem acesso</Badge>}
              </dd>
              {s.notes && <><dt>Observações</dt><dd>{s.notes}</dd></>}
            </dl>
          </div>

          <div className="card">
            <h2 className="card-title">Contratos</h2>
            {s.memberships.length === 0 ? <Empty title="Sem matrícula" /> : (
              <ul className="timeline">
                {s.memberships.map((m) => (
                  <li key={m.id}>
                    <span>
                      <strong>{m.plan.name}</strong>
                      <span className="muted" style={{ display: 'block', fontSize: 12 }}>
                        {formatMoney(m.priceCents)} · {formatDate(m.startDate)}{m.endDate && ` → ${formatDate(m.endDate)}`}
                      </span>
                    </span>
                    {m.status === 'ACTIVE' ? (
                      <button className="btn btn-sm btn-ghost btn-danger"
                        onClick={() => confirm('Cancelar matrícula? Cobranças futuras serão canceladas.') && cancelMembership.mutate(m.id)}>Cancelar</button>
                    ) : <Badge tone="neutral">{m.status === 'CANCELED' ? 'Cancelada' : 'Encerrada'}</Badge>}
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="card">
            <h2 className="card-title">Últimas presenças</h2>
            {s.checkIns.length === 0 ? <Empty title="Sem check-ins" /> : (
              <ul className="timeline">
                {s.checkIns.map((c) => (
                  <li key={c.id}><span>{c.modality.name}</span><span className="mono muted">{formatDateTime(c.checkedAt)}</span></li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </div>

      {communityInvite.error && <div className="alert alert-bad">{errorMessage(communityInvite.error)}</div>}
      {inviteUrl && <Modal title="Convite para a comunidade" onClose={() => setInviteUrl(null)}>
        <p>Envie este link para <strong>{s.email}</strong>. O convite expira em 14 dias e só pode ser usado com uma conta cadastrada com esse e-mail.</p>
        <input className="input" readOnly value={inviteUrl} onFocus={(event) => event.currentTarget.select()} />
        <div className="modal-foot">
          <button className="btn btn-ghost" onClick={() => setInviteUrl(null)}>Fechar</button>
          <button className="btn btn-primary" onClick={async () => {
            try {
              await navigator.clipboard.writeText(inviteUrl);
              setInviteCopied(true);
              setInviteCopyError(false);
            } catch {
              setInviteCopied(false);
              setInviteCopyError(true);
            }
          }}>{inviteCopied ? 'Link copiado' : 'Copiar link'}</button>
        </div>
        {inviteCopyError && <p className="alert alert-bad">Não foi possível copiar o link. Selecione o campo para copiá-lo manualmente.</p>}
      </Modal>}

      {editing && <StudentForm student={s} onClose={() => setEditing(false)} />}
      {enrolling && <MembershipForm student={s} onClose={() => setEnrolling(false)} />}
      {credentials && (
        <Modal title="Acesso ao app liberado" onClose={() => setCredentials(null)}>
          <p style={{ marginTop: 0 }}>Repasse ao aluno. A senha <strong>não será exibida novamente</strong>; ele pode trocá-la no app.</p>
          <dl className="kv" style={{ fontSize: 16 }}>
            <dt>E-mail</dt><dd className="mono">{credentials.email}</dd>
            <dt>Senha</dt><dd className="mono" style={{ fontSize: 22, color: 'var(--blood)' }}>{credentials.password}</dd>
          </dl>
          <div className="modal-foot"><button className="btn btn-primary" onClick={() => setCredentials(null)}>Entendi</button></div>
        </Modal>
      )}
      {paying && <PayInvoiceModal invoice={paying} onClose={() => setPaying(null)} />}
    </>
  );
}

/** Ranks vêm ordenados do mais recente; mantém o primeiro de cada modalidade. */
export function latestPerModality(ranks: Rank[]): Rank[] {
  const seen = new Set<string>();
  return ranks.filter((r) => !seen.has(r.modality.id) && seen.add(r.modality.id));
}
