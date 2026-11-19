import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, type Paginated, toQuery } from '../lib/api';
import { CYCLE_LABEL, formatMoney, PAYMENT_LABEL, parseMoney, todayIso } from '../lib/format';
import type { Invoice, Plan, Student } from '../lib/types';
import { Field, ModalForm } from './ui';

/** Invalida tudo o que depende de dinheiro/matrícula. */
export function useInvalidateFinance() {
  const queryClient = useQueryClient();
  return () => {
    for (const key of ['invoices', 'memberships', 'dashboard', 'student', 'students', 'graduations']) {
      queryClient.invalidateQueries({ queryKey: [key] });
    }
  };
}

export function PayInvoiceModal({ invoice, onClose }: { invoice: Invoice; onClose: () => void }) {
  const invalidate = useInvalidateFinance();
  const [paymentMethod, setPaymentMethod] = useState('PIX');
  const [paidAt, setPaidAt] = useState(todayIso());
  const pay = useMutation({
    mutationFn: () => api(`/invoices/${invoice.id}/pay`, { body: { paymentMethod, paidAt } }),
    onSuccess: () => { invalidate(); onClose(); },
  });

  return (
    <ModalForm title="Registrar pagamento" submitLabel={`Receber ${formatMoney(invoice.amountCents)}`}
      onClose={onClose} onSubmit={() => pay.mutate()} pending={pay.isPending} error={pay.error}>
      <p className="span-2" style={{ margin: 0 }}>{invoice.student?.name && <strong>{invoice.student.name} · </strong>}{invoice.description}</p>
      <Field label="Forma de pagamento">
        <select className="select" value={paymentMethod} onChange={(e) => setPaymentMethod(e.target.value)}>
          {Object.entries(PAYMENT_LABEL).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
      </Field>
      <Field label="Data do pagamento"><input className="input" type="date" required value={paidAt} onChange={(e) => setPaidAt(e.target.value)} /></Field>
    </ModalForm>
  );
}

export function MembershipForm({ student, onClose }: { student?: Student; onClose: () => void }) {
  const invalidate = useInvalidateFinance();
  const plans = useQuery({ queryKey: ['plans'], queryFn: () => api<Plan[]>('/plans') });
  const [studentSearch, setStudentSearch] = useState('');
  const students = useQuery({
    queryKey: ['students', { search: studentSearch, pick: true }],
    queryFn: () => api<Paginated<Student>>(`/students${toQuery({ search: studentSearch, pageSize: 8 })}`),
    enabled: !student,
  });
  const [form, setForm] = useState({ studentId: student?.id ?? '', planId: '', startDate: todayIso(), endDate: '', price: '' });
  const activePlans = plans.data?.filter((p) => p.active) ?? [];
  const selectedPlan = activePlans.find((p) => p.id === form.planId);

  const create = useMutation({
    mutationFn: () => api('/memberships', {
      body: {
        studentId: form.studentId,
        planId: form.planId,
        startDate: form.startDate,
        ...(form.endDate && { endDate: form.endDate }),
        ...(form.price && { priceCents: parseMoney(form.price) }),
      },
    }),
    onSuccess: () => { invalidate(); onClose(); },
  });

  return (
    <ModalForm title="Nova matrícula" submitLabel="Matricular" onClose={onClose} onSubmit={() => create.mutate()} pending={create.isPending} error={create.error}>
      {student ? (
        <p className="span-2" style={{ margin: 0 }}>Aluno: <strong>{student.name}</strong></p>
      ) : (
        <Field label="Aluno" span>
          <input className="input" placeholder="Buscar aluno…" value={studentSearch} onChange={(e) => setStudentSearch(e.target.value)} />
          <select className="select" required size={5} value={form.studentId} onChange={(e) => setForm({ ...form, studentId: e.target.value })} style={{ marginTop: 6 }}>
            {students.data?.items.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </Field>
      )}
      <Field label="Plano" span>
        <select className="select" required value={form.planId} onChange={(e) => setForm({ ...form, planId: e.target.value })}>
          <option value="">Selecione…</option>
          {activePlans.map((p) => (
            <option key={p.id} value={p.id}>{p.name} — {formatMoney(p.priceCents)} ({CYCLE_LABEL[p.billingCycleMonths]})</option>
          ))}
        </select>
      </Field>
      <Field label="Início"><input className="input" type="date" required value={form.startDate} onChange={(e) => setForm({ ...form, startDate: e.target.value })} /></Field>
      <Field label="Fim do contrato (opcional)"><input className="input" type="date" value={form.endDate} onChange={(e) => setForm({ ...form, endDate: e.target.value })} /></Field>
      <Field label="Valor negociado (opcional)" span>
        <input className="input" inputMode="decimal" placeholder={selectedPlan ? formatMoney(selectedPlan.priceCents) : 'Usa o valor do plano'}
          value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
      </Field>
    </ModalForm>
  );
}
