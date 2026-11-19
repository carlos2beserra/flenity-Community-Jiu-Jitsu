import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { WEEKDAYS } from '../lib/format';
import type { ClassSchedule, Modality, User } from '../lib/types';
import { Field, ModalForm, PageHeader } from '../components/ui';

const ORDER = [1, 2, 3, 4, 5, 6, 0];

export function SchedulePage() {
  const classes = useQuery({ queryKey: ['classes'], queryFn: () => api<ClassSchedule[]>('/classes') });
  const [editing, setEditing] = useState<ClassSchedule | 'new' | null>(null);
  const today = new Date().getDay();

  return (
    <>
      <PageHeader kicker="Jiu-Jitsu" title="Agenda de aulas" actions={<button className="btn btn-primary" onClick={() => setEditing('new')}>+ Nova aula</button>} />
      <div className="week">
        {ORDER.map((weekday) => (
          <section key={weekday} className={`week-day${weekday === today ? ' today' : ''}`}>
            <h3>{WEEKDAYS[weekday]}</h3>
            {classes.data?.filter((c) => c.weekday === weekday).map((c) => (
              <button key={c.id} className="slot" onClick={() => setEditing(c)}>
                <div className="time">{c.startTime}–{c.endTime}</div>
                <div className="name">{c.name}</div>
                <div className="who">{c.modality.name} · {c.instructor?.name ?? 'sem instrutor'}</div>
              </button>
            ))}
          </section>
        ))}
      </div>
      {editing && <ClassForm cls={editing === 'new' ? undefined : editing} onClose={() => setEditing(null)} />}
    </>
  );
}

function ClassForm({ cls, onClose }: { cls?: ClassSchedule; onClose: () => void }) {
  const queryClient = useQueryClient();
  const modalities = useQuery({ queryKey: ['modalities'], queryFn: () => api<Modality[]>('/modalities') });
  const users = useQuery({ queryKey: ['users'], queryFn: () => api<User[]>('/users') });
  const [form, setForm] = useState({
    name: cls?.name ?? '', modalityId: cls?.modality.id ?? '', instructorId: cls?.instructor?.id ?? '',
    weekday: String(cls?.weekday ?? 1), startTime: cls?.startTime ?? '19:00', endTime: cls?.endTime ?? '20:00', capacity: String(cls?.capacity ?? 30),
  });
  const set = (key: keyof typeof form) => (e: { target: { value: string } }) => setForm({ ...form, [key]: e.target.value });
  const done = () => { queryClient.invalidateQueries({ queryKey: ['classes'] }); onClose(); };

  const save = useMutation({
    mutationFn: () => {
      const body = {
        name: form.name, modalityId: form.modalityId, weekday: Number(form.weekday), startTime: form.startTime,
        endTime: form.endTime, capacity: Number(form.capacity), ...(form.instructorId && { instructorId: form.instructorId }),
      };
      return cls ? api(`/classes/${cls.id}`, { method: 'PATCH', body }) : api('/classes', { body });
    },
    onSuccess: done,
  });
  const remove = useMutation({ mutationFn: () => api(`/classes/${cls!.id}`, { method: 'DELETE' }), onSuccess: done });

  return (
    <ModalForm title={cls ? 'Editar aula' : 'Nova aula'} onClose={onClose} onSubmit={() => save.mutate()} pending={save.isPending} error={save.error ?? remove.error}>
      <Field label="Nome da aula" span><input className="input" required value={form.name} onChange={set('name')} placeholder="Ex.: Jiu-Jitsu fundamentos ou No-Gi" /></Field>
      <Field label="Modalidade">
        <select className="select" required value={form.modalityId} onChange={set('modalityId')}>
          <option value="">Selecione…</option>
          {modalities.data?.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
        </select>
      </Field>
      <Field label="Instrutor">
        <select className="select" value={form.instructorId} onChange={set('instructorId')}>
          <option value="">—</option>
          {users.data?.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
        </select>
      </Field>
      <Field label="Dia da semana">
        <select className="select" value={form.weekday} onChange={set('weekday')}>
          {ORDER.map((d) => <option key={d} value={d}>{WEEKDAYS[d]}</option>)}
        </select>
      </Field>
      <Field label="Capacidade"><input className="input" type="number" min={1} value={form.capacity} onChange={set('capacity')} /></Field>
      <Field label="Início"><input className="input" type="time" required value={form.startTime} onChange={set('startTime')} /></Field>
      <Field label="Fim"><input className="input" type="time" required value={form.endTime} onChange={set('endTime')} /></Field>
      {cls && (
        <div className="span-2">
          <button type="button" className="btn btn-sm btn-ghost btn-danger" onClick={() => confirm('Excluir aula?') && remove.mutate()}>Excluir aula</button>
        </div>
      )}
    </ModalForm>
  );
}
