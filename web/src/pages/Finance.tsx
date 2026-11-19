import { useState } from 'react';
import { keepPreviousData, useMutation, useQuery } from '@tanstack/react-query';
import { Link, useSearchParams } from 'react-router-dom';
import { api, type Paginated, toQuery } from '../lib/api';
import { formatDate, formatMoney, INVOICE_STATE_LABEL, invoiceState, PAYMENT_LABEL, parseMoney, todayIso } from '../lib/format';
import type { Invoice, Student } from '../lib/types';
import { PayInvoiceModal, useInvalidateFinance } from '../components/forms';
import { Badge, Empty, errorMessage, Field, Loading, ModalForm, PageHeader, Pager } from '../components/ui';
import { INVOICE_TONE } from './StudentDetail';

const FILTERS = [
  { value: '', label: 'Todas' },
  { value: 'OVERDUE', label: 'Vencidas' },
  { value: 'PENDING', label: 'Em aberto' },
  { value: 'PAID', label: 'Pagas' },
];

export function FinancePage() {
  const [params, setParams] = useSearchParams();
  const status = params.get('status') ?? '';
  const [month, setMonth] = useState(params.get('status') === 'OVERDUE' ? '' : todayIso().slice(0, 7));
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [paying, setPaying] = useState<Invoice | null>(null);
  const [creating, setCreating] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const invalidate = useInvalidateFinance();

  const invoices = useQuery({
    queryKey: ['invoices', { status, month, search, page }],
    queryFn: () => api<Paginated<Invoice> & { totalAmountCents: number }>(`/invoices${toQuery({ status, month, search, page, pageSize: 25 })}`),
    placeholderData: keepPreviousData,
  });

  const generate = useMutation({
    mutationFn: () => {
      const [year, m] = (month || todayIso().slice(0, 7)).split('-').map(Number);
      return api<{ created: number; eligible: number }>('/invoices/generate', { body: { year, month: m } });
    },
    onSuccess: (r) => { invalidate(); setNotice(`${r.created} mensalidade(s) gerada(s) · ${r.eligible - r.created} já existiam`); },
  });
  const cancel = useMutation({ mutationFn: (id: string) => api(`/invoices/${id}/cancel`, { method: 'POST' }), onSuccess: invalidate });

  const setStatus = (value: string) => { setParams(value ? { status: value } : {}); setPage(1); };

  return (
    <>
      <PageHeader kicker="Contas a receber" title="Financeiro" actions={<>
        <button className="btn" onClick={() => setCreating(true)}>+ Cobrança avulsa</button>
        <button className="btn btn-primary" disabled={generate.isPending} onClick={() => generate.mutate()}>Gerar mensalidades do mês</button>
      </>} />
      {notice && <div className="alert alert-good" style={{ marginBottom: 12 }}>{notice}</div>}
      {(generate.error || cancel.error) && <div className="alert alert-bad" style={{ marginBottom: 12 }}>{errorMessage(generate.error ?? cancel.error)}</div>}

      <div className="toolbar">
        <div className="segmented" role="group" aria-label="Status">
          {FILTERS.map((f) => <button key={f.value} className={status === f.value ? 'on' : ''} onClick={() => setStatus(f.value)}>{f.label}</button>)}
        </div>
        <input className="input" type="month" style={{ width: 170 }} value={month} onChange={(e) => { setMonth(e.target.value); setPage(1); }} aria-label="Mês de vencimento" />
        <input className="input" placeholder="Buscar aluno" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} />
        {invoices.data && <span className="mono" style={{ marginLeft: 'auto' }}>Total: <strong>{formatMoney(invoices.data.totalAmountCents)}</strong></span>}
      </div>

      {!invoices.data ? <Loading /> : (
        <div className="table-wrap">
          {invoices.data.items.length === 0 ? <Empty title="Nada por aqui" /> : (
            <table>
              <thead><tr><th>Vencimento</th><th>Aluno</th><th>Descrição</th><th className="num">Valor</th><th>Status</th><th /></tr></thead>
              <tbody>
                {invoices.data.items.map((inv) => {
                  const state = invoiceState(inv);
                  return (
                    <tr key={inv.id}>
                      <td className="mono">{formatDate(inv.dueDate)}</td>
                      <td><Link className="row-link" to={`/alunos/${inv.studentId}`}>{inv.student?.name}</Link></td>
                      <td className="muted">{inv.description}</td>
                      <td className="num mono">{formatMoney(inv.amountCents)}</td>
                      <td>
                        <Badge tone={INVOICE_TONE[state]}>{INVOICE_STATE_LABEL[state]}</Badge>
                        {inv.paymentMethod && <span className="muted" style={{ fontSize: 12 }}> · {PAYMENT_LABEL[inv.paymentMethod]}</span>}
                      </td>
                      <td className="actions">
                        {inv.status === 'PENDING' && <>
                          {inv.student?.phone && (
                            <a className="btn btn-sm btn-ghost" target="_blank" rel="noreferrer"
                              href={`https://wa.me/55${inv.student.phone.replace(/\D/g, '')}?text=${encodeURIComponent(
                                `Olá ${inv.student.name.split(' ')[0]}! Lembrete: ${inv.description} de ${formatMoney(inv.amountCents)} com vencimento em ${formatDate(inv.dueDate)}. Oss!`)}`}>
                              Cobrar
                            </a>
                          )}
                          <button className="btn btn-sm btn-ghost btn-danger" onClick={() => confirm('Cancelar cobrança?') && cancel.mutate(inv.id)}>Cancelar</button>
                          <button className="btn btn-sm btn-primary" onClick={() => setPaying(inv)}>Receber</button>
                        </>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
          <Pager page={page} pageSize={25} total={invoices.data.total} onPage={setPage} />
        </div>
      )}
      {paying && <PayInvoiceModal invoice={paying} onClose={() => setPaying(null)} />}
      {creating && <InvoiceForm onClose={() => setCreating(false)} />}
    </>
  );
}

function InvoiceForm({ onClose }: { onClose: () => void }) {
  const invalidate = useInvalidateFinance();
  const [search, setSearch] = useState('');
  const students = useQuery({
    queryKey: ['students', { search, pick: true }],
    queryFn: () => api<Paginated<Student>>(`/students${toQuery({ search, pageSize: 8 })}`),
  });
  const [form, setForm] = useState({ studentId: '', description: '', amount: '', dueDate: todayIso() });
  const create = useMutation({
    mutationFn: () => api('/invoices', {
      body: { studentId: form.studentId, description: form.description, amountCents: parseMoney(form.amount), dueDate: form.dueDate },
    }),
    onSuccess: () => { invalidate(); onClose(); },
  });

  return (
    <ModalForm title="Cobrança avulsa" onClose={onClose} onSubmit={() => create.mutate()} pending={create.isPending} error={create.error}>
      <Field label="Aluno" span>
        <input className="input" placeholder="Buscar aluno…" value={search} onChange={(e) => setSearch(e.target.value)} />
        <select className="select" required size={4} value={form.studentId} onChange={(e) => setForm({ ...form, studentId: e.target.value })} style={{ marginTop: 6 }}>
          {students.data?.items.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </Field>
      <Field label="Descrição" span><input className="input" required placeholder="Ex.: Kimono, exame de faixa, seminário" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></Field>
      <Field label="Valor (R$)"><input className="input" required inputMode="decimal" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} /></Field>
      <Field label="Vencimento"><input className="input" type="date" required value={form.dueDate} onChange={(e) => setForm({ ...form, dueDate: e.target.value })} /></Field>
    </ModalForm>
  );
}
