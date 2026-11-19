import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { CYCLE_LABEL, formatMoney, parseMoney } from '../lib/format';
import type { Modality, Plan } from '../lib/types';
import { Badge, Empty, Field, Loading, ModalForm, PageHeader } from '../components/ui';

export function PlansPage() {
  const plans = useQuery({ queryKey: ['plans'], queryFn: () => api<Plan[]>('/plans') });
  const [editing, setEditing] = useState<Plan | 'new' | null>(null);

  return (
    <>
      <PageHeader kicker="Catálogo" title="Planos" actions={<button className="btn btn-primary" onClick={() => setEditing('new')}>+ Novo plano</button>} />
      {!plans.data ? <Loading /> : plans.data.length === 0 ? <Empty title="Nenhum plano">Cadastre um plano para as aulas de Jiu-Jitsu.</Empty> : (
        <div className="grid grid-3 reveal">
          {plans.data.map((p) => (
            <article key={p.id} className="card" style={{ opacity: p.active ? 1 : 0.55 }}>
              <h2 className="card-title">{p.name} {!p.active && <Badge tone="neutral">Inativo</Badge>}</h2>
              <div className="stat-value" style={{ marginTop: 0 }}>{formatMoney(p.priceCents)}</div>
              <div className="stat-sub">
                {CYCLE_LABEL[p.billingCycleMonths]} · {p.weeklyLimit ? `${p.weeklyLimit}x por semana` : 'treinos livres'}
              </div>
              <div className="checks" style={{ margin: '14px 0' }}>
                {p.modalities.map(({ modality }) => <span key={modality.id} className="check-pill">{modality.name}</span>)}
              </div>
              <button className="btn btn-sm" onClick={() => setEditing(p)}>Editar</button>
            </article>
          ))}
        </div>
      )}
      {editing && <PlanForm plan={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function PlanForm({ plan, onClose }: { plan?: Plan; onClose: () => void }) {
  const queryClient = useQueryClient();
  const modalities = useQuery({ queryKey: ['modalities'], queryFn: () => api<Modality[]>('/modalities') });
  const [form, setForm] = useState({
    name: plan?.name ?? '',
    price: plan ? (plan.priceCents / 100).toFixed(2).replace('.', ',') : '',
    billingCycleMonths: String(plan?.billingCycleMonths ?? 1),
    weeklyLimit: plan?.weeklyLimit ? String(plan.weeklyLimit) : '',
    active: plan?.active ?? true,
    modalityIds: plan?.modalities.map((m) => m.modality.id) ?? [],
  });

  const toggleModality = (id: string) =>
    setForm({ ...form, modalityIds: form.modalityIds.includes(id) ? form.modalityIds.filter((m) => m !== id) : [...form.modalityIds, id] });

  const save = useMutation({
    mutationFn: () => {
      const body = {
        name: form.name,
        priceCents: parseMoney(form.price),
        billingCycleMonths: Number(form.billingCycleMonths),
        weeklyLimit: form.weeklyLimit ? Number(form.weeklyLimit) : null,
        modalityIds: form.modalityIds,
        active: form.active,
      };
      return plan ? api(`/plans/${plan.id}`, { method: 'PATCH', body }) : api('/plans', { body });
    },
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['plans'] }); onClose(); },
  });

  return (
    <ModalForm title={plan ? 'Editar plano' : 'Novo plano'} onClose={onClose} onSubmit={() => save.mutate()} pending={save.isPending} error={save.error}>
      <Field label="Nome do plano" span><input className="input" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></Field>
      <Field label="Valor por ciclo (R$)"><input className="input" required inputMode="decimal" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} /></Field>
      <Field label="Ciclo de cobrança">
        <select className="select" value={form.billingCycleMonths} onChange={(e) => setForm({ ...form, billingCycleMonths: e.target.value })}>
          {Object.entries(CYCLE_LABEL).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
      </Field>
      <Field label="Limite semanal de aulas"><input className="input" type="number" min={1} max={14} placeholder="Livre" value={form.weeklyLimit} onChange={(e) => setForm({ ...form, weeklyLimit: e.target.value })} /></Field>
      <Field label="Situação">
        <select className="select" value={form.active ? '1' : '0'} onChange={(e) => setForm({ ...form, active: e.target.value === '1' })}>
          <option value="1">Ativo (disponível para venda)</option>
          <option value="0">Inativo</option>
        </select>
      </Field>
      <div className="field span-2">
        <span>Modalidade</span>
        <div className="checks">
          {modalities.data?.map((m) => (
            <label key={m.id} className="check-pill">
              <input type="checkbox" checked={form.modalityIds.includes(m.id)} onChange={() => toggleModality(m.id)} />
              {m.name}
            </label>
          ))}
        </div>
      </div>
    </ModalForm>
  );
}
