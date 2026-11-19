import { useState } from 'react';
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import { api, type Paginated, toQuery } from '../lib/api';
import { CYCLE_LABEL, formatDate, formatMoney, STUDENT_STATUS, todayIso } from '../lib/format';
import type { Plan, Student } from '../lib/types';
import { Badge, Empty, errorMessage, Field, Loading, ModalForm, PageHeader, Pager, Person } from '../components/ui';

export const STATUS_TONE = { ACTIVE: 'good', INACTIVE: 'neutral', SUSPENDED: 'warn' } as const;

export function StudentsPage() {
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [creating, setCreating] = useState(false);

  const students = useQuery({
    queryKey: ['students', { search, status, page }],
    queryFn: () => api<Paginated<Student>>(`/students${toQuery({ search, status, page, pageSize: 20 })}`),
    placeholderData: keepPreviousData,
  });

  return (
    <>
      <PageHeader kicker="Cadastro" title="Alunos" actions={<button className="btn btn-primary" onClick={() => setCreating(true)}>+ Novo aluno</button>} />
      <div className="toolbar">
        <input className="input" placeholder="Buscar por nome, e-mail ou CPF" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} />
        <select className="select" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }} aria-label="Filtrar status">
          <option value="">Todos os status</option>
          {Object.entries(STUDENT_STATUS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
      </div>
      {!students.data ? <Loading /> : (
        <div className="table-wrap">
          {students.data.items.length === 0 ? <Empty title="Nenhum aluno encontrado" /> : (
            <table>
              <thead><tr><th>Aluno</th><th>Telefone</th><th>Nascimento</th><th>Desde</th><th>Status</th></tr></thead>
              <tbody>
                {students.data.items.map((s) => (
                  <tr key={s.id}>
                    <td><Link to={`/alunos/${s.id}`} className="row-link"><Person name={s.name} sub={s.email} /></Link></td>
                    <td className="mono">{s.phone ?? '—'}</td>
                    <td>{formatDate(s.birthDate)}</td>
                    <td>{formatDate(s.createdAt)}</td>
                    <td><Badge tone={STATUS_TONE[s.status]}>{STUDENT_STATUS[s.status]}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <Pager page={page} pageSize={20} total={students.data.total} onPage={setPage} />
        </div>
      )}
      {creating && <StudentForm onClose={() => setCreating(false)} />}
    </>
  );
}

export function StudentForm({ student, onClose }: { student?: Student; onClose: () => void }) {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const plans = useQuery({
    queryKey: ['plans'],
    queryFn: () => api<Plan[]>('/plans'),
    enabled: !student,
  });
  const [selectedPlanIds, setSelectedPlanIds] = useState<string[]>([]);
  const [membershipStartDate, setMembershipStartDate] = useState(todayIso());
  const [form, setForm] = useState({
    name: student?.name ?? '', email: student?.email ?? '', phone: student?.phone ?? '', cpf: student?.cpf ?? '',
    birthDate: student?.birthDate?.slice(0, 10) ?? '', status: student?.status ?? 'ACTIVE', notes: student?.notes ?? '',
  });
  const set = (key: keyof typeof form) => (e: { target: { value: string } }) => setForm({ ...form, [key]: e.target.value });
  const activePlans = plans.data?.filter((plan) => plan.active && plan.modalities.length > 0) ?? [];
  const selectedPlans = activePlans.filter((plan) => selectedPlanIds.includes(plan.id));
  const selectedModalities = [...new Map(
    selectedPlans.flatMap((plan) => plan.modalities.map(({ modality }) => [modality.id, modality] as const)),
  ).values()];

  const save = useMutation({
    mutationFn: () => {
      const body = Object.fromEntries(Object.entries({ ...form, cpf: form.cpf.replace(/\D/g, '') }).filter(([, v]) => v !== ''));
      return student
        ? api<Student>(`/students/${student.id}`, { method: 'PATCH', body })
        : selectedPlans.length > 0
        ? api<Student>('/students/registration', {
          body: {
            ...body,
            memberships: selectedPlans.map((plan) => ({
              planId: plan.id,
              startDate: membershipStartDate,
            })),
          },
        })
        : api<Student>('/students', { body });
    },
    onSuccess: (saved) => {
      queryClient.invalidateQueries({ queryKey: ['students'] });
      queryClient.invalidateQueries({ queryKey: ['student', saved.id] });
      if (!student && selectedPlans.length > 0) {
        for (const key of ['memberships', 'invoices', 'dashboard', 'graduations']) {
          queryClient.invalidateQueries({ queryKey: [key] });
        }
      }
      onClose();
      if (!student) navigate(`/alunos/${saved.id}`);
    },
  });

  return (
    <ModalForm
      title={student ? 'Editar aluno' : 'Novo aluno'}
      submitLabel={student ? 'Salvar' : selectedPlans.length ? 'Cadastrar e matricular' : 'Cadastrar aluno'}
      onClose={onClose}
      onSubmit={() => save.mutate()}
      pending={save.isPending}
      error={save.error}
    >
      <Field label="Nome completo" span><input className="input" required minLength={2} value={form.name} onChange={set('name')} autoFocus /></Field>
      <Field label="E-mail"><input className="input" type="email" value={form.email} onChange={set('email')} /></Field>
      <Field label="Telefone / WhatsApp"><input className="input" value={form.phone} onChange={set('phone')} /></Field>
      <Field label="CPF"><input className="input" inputMode="numeric" value={form.cpf} onChange={set('cpf')} /></Field>
      <Field label="Nascimento"><input className="input" type="date" value={form.birthDate} onChange={set('birthDate')} /></Field>
      {student && (
        <Field label="Status">
          <select className="select" value={form.status} onChange={set('status')}>
            {Object.entries(STUDENT_STATUS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </Field>
      )}
      {!student && (
        <div className="span-2">
          <div className="field">
            <span>Modalidades e matrículas</span>
            <span className="muted" style={{ fontSize: 13 }}>
              Selecione um ou mais planos. Cada plano libera as modalidades mostradas e gera sua matrícula e cobrança inicial.
            </span>
          </div>
          {plans.error ? (
            <div className="alert alert-bad">{errorMessage(plans.error)}</div>
          ) : !plans.data ? <Loading /> : activePlans.length === 0 ? (
            <Empty title="Nenhum plano ativo">Cadastre planos antes de incluir modalidades na matrícula.</Empty>
          ) : (
            <div className="grid grid-2" style={{ marginTop: 10 }}>
              {activePlans.map((plan) => {
                const checked = selectedPlanIds.includes(plan.id);
                return (
                  <label key={plan.id} className="card" style={{
                    display: 'flex', alignItems: 'flex-start', gap: 10, padding: 14, cursor: 'pointer',
                    borderColor: checked ? 'var(--blood)' : undefined,
                    background: checked ? 'rgba(22, 137, 239, 0.06)' : undefined,
                  }}>
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => setSelectedPlanIds((current) => checked
                        ? current.filter((id) => id !== plan.id)
                        : [...current, plan.id])}
                      aria-label={`Selecionar plano ${plan.name}`}
                    />
                    <span>
                      <strong>{plan.name}</strong>
                      <span className="muted" style={{ display: 'block', marginTop: 3 }}>
                        {formatMoney(plan.priceCents)} · {CYCLE_LABEL[plan.billingCycleMonths]}
                      </span>
                      <span className="check-pills" style={{ display: 'flex', flexWrap: 'wrap', gap: 5, marginTop: 8 }}>
                        {plan.modalities.length
                          ? plan.modalities.map(({ modality }) => <span key={modality.id} className="check-pill">{modality.name}</span>)
                          : <span className="muted">Sem modalidade vinculada</span>}
                      </span>
                    </span>
                  </label>
                );
              })}
            </div>
          )}
          {selectedPlans.length > 0 && (
            <>
              <div className="alert" style={{ marginTop: 12 }}>
                Modalidades do aluno: <strong>{selectedModalities.map(({ name }) => name).join(', ') || 'nenhuma modalidade vinculada aos planos selecionados'}</strong>
              </div>
              <Field label="Início das matrículas">
                <input className="input" type="date" required value={membershipStartDate}
                  onChange={(event) => setMembershipStartDate(event.target.value)} />
              </Field>
            </>
          )}
        </div>
      )}
      <Field label="Observações (lesões, restrições…)" span><textarea className="textarea" value={form.notes} onChange={set('notes')} /></Field>
    </ModalForm>
  );
}
