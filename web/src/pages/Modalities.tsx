import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import type { Belt, Modality } from '../lib/types';
import { BeltBadge } from '../components/BeltBadge';
import { Empty, errorMessage, Loading, Modal, PageHeader } from '../components/ui';

type BeltDraft = Omit<Belt, 'id'>;

export function ModalitiesPage() {
  const modalities = useQuery({ queryKey: ['modalities'], queryFn: () => api<Modality[]>('/modalities') });
  const [editingBelts, setEditingBelts] = useState<Modality | null>(null);

  return (
    <>
      <PageHeader kicker="Arte marcial" title="Jiu-Jitsu" />
      {!modalities.data ? <Loading /> : modalities.data.length === 0 ? <Empty title="Jiu-Jitsu não configurado" /> : (
        <div className="grid grid-2 reveal">
          {modalities.data.map((m) => (
            <article key={m.id} className="card">
              <h2 className="card-title">{m.name} <button className="btn btn-sm" onClick={() => setEditingBelts(m)}>Editar faixas</button></h2>
              <ul className="timeline">
                {m.belts.map((b) => (
                  <li key={b.id}>
                    <BeltBadge name={b.name} color={b.color} degree={0} showLabel />
                    <span className="mono muted" style={{ fontSize: 12 }}>{b.minClasses} aulas/grau · {b.maxDegrees} graus</span>
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      )}
      {editingBelts && <BeltEditor modality={editingBelts} onClose={() => setEditingBelts(null)} />}
    </>
  );
}

function BeltEditor({ modality, onClose }: { modality: Modality; onClose: () => void }) {
  const queryClient = useQueryClient();
  const [belts, setBelts] = useState<BeltDraft[]>(modality.belts.map(({ name, color, order, minClasses, maxDegrees }) => ({ name, color, order, minClasses, maxDegrees })));
  const update = (index: number, patch: Partial<BeltDraft>) => setBelts(belts.map((b, i) => (i === index ? { ...b, ...patch } : b)));
  const save = useMutation({
    mutationFn: () => api(`/modalities/${modality.id}/belts`, { method: 'PUT', body: { belts: belts.map((b, order) => ({ ...b, order })) } }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['modalities'] }); onClose(); },
  });

  return (
    <Modal title={`Régua — ${modality.name}`} onClose={onClose}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {belts.map((b, i) => (
          <div key={i} style={{ display: 'grid', gridTemplateColumns: '40px 1fr 70px 70px 32px', gap: 6, alignItems: 'center' }}>
            <input type="color" value={b.color} onChange={(e) => update(i, { color: e.target.value })} aria-label="Cor" style={{ width: 36, height: 34, border: 0, background: 'none' }} />
            <input className="input" value={b.name} onChange={(e) => update(i, { name: e.target.value })} aria-label="Nome da faixa" />
            <input className="input" type="number" min={0} value={b.minClasses} onChange={(e) => update(i, { minClasses: Number(e.target.value) })} aria-label="Aulas mínimas" title="Aulas mínimas por graduação" />
            <input className="input" type="number" min={0} max={10} value={b.maxDegrees} onChange={(e) => update(i, { maxDegrees: Number(e.target.value) })} aria-label="Graus" title="Quantidade de graus" />
            <button className="btn btn-sm btn-ghost btn-danger" onClick={() => setBelts(belts.filter((_, j) => j !== i))} aria-label="Remover" disabled={belts.length === 1}>×</button>
          </div>
        ))}
        <span className="muted" style={{ fontSize: 12 }}>Ordem de cima para baixo · colunas: aulas mínimas por graduação, graus por faixa.</span>
        <button className="btn btn-sm" style={{ alignSelf: 'flex-start' }}
          onClick={() => setBelts([...belts, { name: 'Nova faixa', color: '#888888', order: belts.length, minClasses: 40, maxDegrees: 4 }])}>+ Adicionar faixa</button>
      </div>
      {save.error && <div className="alert alert-bad" style={{ marginTop: 14 }}>{errorMessage(save.error)}</div>}
      <div className="modal-foot">
        <button className="btn btn-ghost" onClick={onClose}>Cancelar</button>
        <button className="btn btn-primary" disabled={save.isPending} onClick={() => save.mutate()}>Salvar régua</button>
      </div>
    </Modal>
  );
}
