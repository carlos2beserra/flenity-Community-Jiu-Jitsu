import { type DragEvent, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import type { Lead, LeadStatus, Student } from '../lib/types';
import { Field, ModalForm, PageHeader } from '../components/ui';

const COLUMNS: { status: LeadStatus; label: string }[] = [
  { status: 'NEW', label: 'Novo' },
  { status: 'CONTACTED', label: 'Contatado' },
  { status: 'TRIAL', label: 'Aula experimental' },
  { status: 'CONVERTED', label: 'Matriculado' },
  { status: 'LOST', label: 'Perdido' },
];

/** Funil de vendas em Kanban: arraste os cards entre as colunas. */
export function LeadsPage() {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const leads = useQuery({ queryKey: ['leads'], queryFn: () => api<Lead[]>('/leads') });
  const [editing, setEditing] = useState<Lead | 'new' | null>(null);
  const [dropTarget, setDropTarget] = useState<LeadStatus | null>(null);

  const move = useMutation({
    mutationFn: ({ id, status }: { id: string; status: LeadStatus }) => api(`/leads/${id}`, { method: 'PATCH', body: { status } }),
    onMutate: async ({ id, status }) => {
      queryClient.setQueryData<Lead[]>(['leads'], (old) => old?.map((l) => (l.id === id ? { ...l, status } : l)));
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['leads'] }),
  });
  const convert = useMutation({
    mutationFn: (id: string) => api<Student>(`/leads/${id}/convert`, { method: 'POST' }),
    onSuccess: (student) => {
      queryClient.invalidateQueries({ queryKey: ['leads'] });
      navigate(`/alunos/${student.id}`);
    },
  });

  const onDrop = (status: LeadStatus) => (e: DragEvent) => {
    e.preventDefault();
    setDropTarget(null);
    const id = e.dataTransfer.getData('text/plain');
    if (status === 'CONVERTED') {
      if (confirm('Converter este lead em aluno?')) convert.mutate(id);
      return;
    }
    move.mutate({ id, status });
  };

  return (
    <>
      <PageHeader kicker="Funil comercial" title="CRM de leads" actions={<button className="btn btn-primary" onClick={() => setEditing('new')}>+ Novo lead</button>} />
      <div className="kanban">
        {COLUMNS.map((col) => {
          const items = leads.data?.filter((l) => l.status === col.status) ?? [];
          return (
            <section key={col.status} className={`kanban-col${dropTarget === col.status ? ' drop' : ''}`}
              onDragOver={(e) => { e.preventDefault(); setDropTarget(col.status); }}
              onDragLeave={() => setDropTarget(null)} onDrop={onDrop(col.status)}>
              <h3>{col.label} <span>{items.length}</span></h3>
              {items.map((lead) => (
                <article key={lead.id} className="lead-card" draggable onDragStart={(e) => e.dataTransfer.setData('text/plain', lead.id)}>
                  <strong>{lead.name}</strong>
                  <div className="meta">{[lead.interest, lead.source].filter(Boolean).join(' · ') || '—'}</div>
                  {lead.phone && <div className="meta mono">{lead.phone}</div>}
                  <div className="lead-actions">
                    <button className="btn btn-sm btn-ghost" onClick={() => setEditing(lead)}>Editar</button>
                    {lead.status !== 'CONVERTED' && (
                      <button className="btn btn-sm" disabled={convert.isPending} onClick={() => confirm(`Matricular ${lead.name}?`) && convert.mutate(lead.id)}>Converter</button>
                    )}
                  </div>
                </article>
              ))}
            </section>
          );
        })}
      </div>
      {editing && <LeadForm lead={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function LeadForm({ lead, onClose }: { lead?: Lead; onClose: () => void }) {
  const queryClient = useQueryClient();
  const [form, setForm] = useState({
    name: lead?.name ?? '', phone: lead?.phone ?? '', email: lead?.email ?? '',
    source: lead?.source ?? '', interest: lead?.interest || 'Jiu-Jitsu', notes: lead?.notes ?? '',
  });
  const set = (key: keyof typeof form) => (e: { target: { value: string } }) => setForm({ ...form, [key]: e.target.value });
  const save = useMutation({
    mutationFn: () => {
      const body = Object.fromEntries(Object.entries(form).filter(([, v]) => v !== ''));
      return lead ? api(`/leads/${lead.id}`, { method: 'PATCH', body }) : api('/leads', { body });
    },
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['leads'] }); onClose(); },
  });

  return (
    <ModalForm title={lead ? 'Editar lead' : 'Novo lead'} onClose={onClose} onSubmit={() => save.mutate()} pending={save.isPending} error={save.error}>
      <Field label="Nome" span><input className="input" required value={form.name} onChange={set('name')} autoFocus /></Field>
      <Field label="Telefone / WhatsApp"><input className="input" value={form.phone} onChange={set('phone')} /></Field>
      <Field label="E-mail"><input className="input" type="email" value={form.email} onChange={set('email')} /></Field>
      <Field label="Origem"><input className="input" list="lead-sources" value={form.source} onChange={set('source')} /></Field>
      <Field label="Interesse"><input className="input" value="Jiu-Jitsu" readOnly /></Field>
      <Field label="Anotações" span><textarea className="textarea" value={form.notes} onChange={set('notes')} /></Field>
      <datalist id="lead-sources">{['Instagram', 'Indicação', 'Google', 'Fachada', 'WhatsApp', 'Evento'].map((s) => <option key={s} value={s} />)}</datalist>
    </ModalForm>
  );
}
