import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { api, toQuery } from '../lib/api';
import { formatDate } from '../lib/format';
import type { BoardRow, Modality } from '../lib/types';
import { BeltBadge } from '../components/BeltBadge';
import { Empty, errorMessage, Loading, PageHeader } from '../components/ui';

export function GraduationsPage() {
  const queryClient = useQueryClient();
  const [modalityId, setModalityId] = useState('');
  const [eligibleOnly, setEligibleOnly] = useState(true);
  const modalities = useQuery({ queryKey: ['modalities'], queryFn: () => api<Modality[]>('/modalities') });
  const board = useQuery({
    queryKey: ['graduations', { modalityId, eligibleOnly }],
    queryFn: () => api<BoardRow[]>(`/graduations${toQuery({ modalityId, eligibleOnly })}`),
  });
  const promote = useMutation({
    mutationFn: (row: BoardRow) => api('/graduations/promote', { body: { studentId: row.studentId, modalityId: row.modalityId } }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['graduations'] });
      queryClient.invalidateQueries({ queryKey: ['student'] });
    },
  });

  return (
    <>
      <PageHeader kicker="Régua de evolução" title="Graduações" />
      <div className="toolbar">
        <select className="select" value={modalityId} onChange={(e) => setModalityId(e.target.value)} aria-label="Modalidade">
          <option value="">Todas as modalidades</option>
          {modalities.data?.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
        </select>
        <div className="segmented" role="group" aria-label="Filtro">
          <button className={eligibleOnly ? 'on' : ''} onClick={() => setEligibleOnly(true)}>Aptos</button>
          <button className={!eligibleOnly ? 'on' : ''} onClick={() => setEligibleOnly(false)}>Todos</button>
        </div>
      </div>
      {promote.error && <div className="alert alert-bad" style={{ marginBottom: 12 }}>{errorMessage(promote.error)}</div>}
      {!board.data ? <Loading /> : (
        <div className="table-wrap">
          {board.data.length === 0 ? <Empty title="Ninguém por aqui">Nenhum aluno atingiu a frequência mínima ainda.</Empty> : (
            <table>
              <thead><tr><th>Aluno</th><th>Modalidade</th><th>Graduação atual</th><th>Última promoção</th><th>Frequência</th><th /></tr></thead>
              <tbody>
                {board.data.map((r) => {
                  const pct = Math.min(100, (r.classesSince / Math.max(1, r.minClasses)) * 100);
                  return (
                    <tr key={`${r.studentId}-${r.modalityId}`}>
                      <td><Link className="row-link" to={`/alunos/${r.studentId}`}>{r.studentName}</Link></td>
                      <td>{r.modalityName}</td>
                      <td><BeltBadge name={r.beltName} color={r.beltColor} degree={r.degree} maxDegrees={r.maxDegrees} /></td>
                      <td>{formatDate(r.promotedAt)}</td>
                      <td>
                        <div className={`progress${r.eligible ? ' full' : ''}`}><div style={{ width: `${pct}%` }} /></div>
                        <span className="mono muted" style={{ fontSize: 11 }}>{r.classesSince}/{r.minClasses} aulas</span>
                      </td>
                      <td className="actions">
                        <button className={`btn btn-sm${r.eligible ? ' btn-primary' : ''}`} disabled={promote.isPending}
                          onClick={() => confirm(`Graduar ${r.studentName} em ${r.modalityName}?`) && promote.mutate(r)}>Graduar</button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      )}
    </>
  );
}
