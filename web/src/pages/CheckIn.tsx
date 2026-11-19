import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, type Paginated, toQuery } from '../lib/api';
import { formatTime } from '../lib/format';
import type { CheckIn, ClassSchedule, Modality, Student } from '../lib/types';
import { Empty, PageHeader, Person } from '../components/ui';

type Verdict = { ok: boolean; title: string; detail: string };

/** Modo recepção: busca rápida do aluno, escolha da turma e validação do acesso. */
export function CheckInPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Student | null>(null);
  const [target, setTarget] = useState('');
  const [verdict, setVerdict] = useState<Verdict | null>(null);

  const students = useQuery({
    queryKey: ['students', { search, kiosk: true }],
    queryFn: () => api<Paginated<Student>>(`/students${toQuery({ search, pageSize: 6, status: 'ACTIVE' })}`),
    enabled: search.trim().length >= 2,
  });
  const classesToday = useQuery({ queryKey: ['classes', 'today'], queryFn: () => api<ClassSchedule[]>('/classes/today') });
  const modalities = useQuery({ queryKey: ['modalities'], queryFn: () => api<Modality[]>('/modalities') });
  const recent = useQuery({ queryKey: ['check-ins', 'today'], queryFn: () => api<Paginated<CheckIn>>('/check-ins?pageSize=30') });

  const checkIn = useMutation({
    mutationFn: () => {
      const [kind, id] = target.split(':');
      return api<CheckIn>('/check-ins', { body: { studentId: selected!.id, ...(kind === 'class' ? { classId: id } : { modalityId: id }) } });
    },
    onSuccess: (created) => {
      setVerdict({ ok: true, title: 'Acesso liberado', detail: `${created.student.name} · ${created.modality.name}` });
      setSelected(null);
      setSearch('');
      for (const key of ['check-ins', 'classes', 'dashboard', 'graduations']) queryClient.invalidateQueries({ queryKey: [key] });
    },
    onError: (error) => {
      setVerdict({ ok: false, title: 'Acesso bloqueado', detail: error instanceof ApiError ? error.message : 'Falha ao registrar' });
    },
  });

  return (
    <>
      <PageHeader kicker="Recepção" title="Acesso e presença" />
      <div className="kiosk">
        <div>
          <div className="card">
            <input className="input kiosk-search" placeholder="Nome do aluno…" autoFocus value={search}
              onChange={(e) => { setSearch(e.target.value); setVerdict(null); }} aria-label="Buscar aluno" />
            <div className="kiosk-results">
              {students.data?.items.map((s) => (
                <button key={s.id} className={`kiosk-item${selected?.id === s.id ? ' selected' : ''}`} onClick={() => setSelected(s)}>
                  <Person name={s.name} sub={s.phone} />
                  <span className="mono muted">{selected?.id === s.id ? 'SELECIONADO' : 'SELECIONAR'}</span>
                </button>
              ))}
              {search.length >= 2 && students.data?.items.length === 0 && <Empty title="Nenhum aluno ativo" />}
            </div>

            {selected && (
              <div style={{ marginTop: 18, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                <select className="select" style={{ flex: 1, minWidth: 220 }} value={target} onChange={(e) => setTarget(e.target.value)} aria-label="Aula">
                  <option value="">Escolha uma aula…</option>
                  <optgroup label="Aulas de hoje">
                    {classesToday.data?.map((c) => <option key={c.id} value={`class:${c.id}`}>{c.startTime} · {c.name}</option>)}
                  </optgroup>
                  <optgroup label="Acesso livre">
                    {modalities.data?.map((m) => <option key={m.id} value={`modality:${m.id}`}>{m.name}</option>)}
                  </optgroup>
                </select>
                <button className="btn btn-primary" style={{ padding: '10px 22px', fontSize: 15 }} disabled={!target || checkIn.isPending} onClick={() => checkIn.mutate()}>
                  Confirmar presença
                </button>
              </div>
            )}
          </div>
          {verdict && (
            <div className={`verdict ${verdict.ok ? 'ok' : 'no'}`} role="status">
              {verdict.title}
              <small>{verdict.detail}</small>
            </div>
          )}
        </div>

        <div className="card">
          <h2 className="card-title">Presenças de hoje <small>{recent.data?.total ?? 0}</small></h2>
          {recent.data?.items.length ? (
            <ul className="timeline">
              {recent.data.items.map((c) => (
                <li key={c.id}>
                  <span><strong>{c.student.name}</strong><span className="muted" style={{ display: 'block', fontSize: 12 }}>{c.class?.name ?? c.modality.name}</span></span>
                  <span className="mono muted">{formatTime(c.checkedAt)}</span>
                </li>
              ))}
            </ul>
          ) : <Empty title="Sem acessos hoje">Ninguém fez check-in hoje.</Empty>}
        </div>
      </div>
    </>
  );
}
