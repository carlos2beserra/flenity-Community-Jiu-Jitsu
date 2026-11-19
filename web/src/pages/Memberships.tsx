import { useState } from 'react';
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { api, type Paginated, toQuery } from '../lib/api';
import { CYCLE_LABEL, formatDate, formatMoney } from '../lib/format';
import type { Membership } from '../lib/types';
import { MembershipForm } from '../components/forms';
import { Badge, Empty, Loading, PageHeader, Pager } from '../components/ui';

const STATUS = { ACTIVE: ['good', 'Ativa'], CANCELED: ['neutral', 'Cancelada'], EXPIRED: ['warn', 'Encerrada'] } as const;

export function MembershipsPage() {
  const [status, setStatus] = useState('ACTIVE');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [creating, setCreating] = useState(false);
  const memberships = useQuery({
    queryKey: ['memberships', { status, search, page }],
    queryFn: () => api<Paginated<Membership>>(`/memberships${toQuery({ status, search, page, pageSize: 25 })}`),
    placeholderData: keepPreviousData,
  });

  return (
    <>
      <PageHeader kicker="Contratos" title="Matrículas" actions={<button className="btn btn-primary" onClick={() => setCreating(true)}>+ Nova matrícula</button>} />
      <div className="toolbar">
        <div className="segmented" role="group" aria-label="Status">
          {[['ACTIVE', 'Ativas'], ['CANCELED', 'Canceladas'], ['', 'Todas']].map(([value, label]) => (
            <button key={value} className={status === value ? 'on' : ''} onClick={() => { setStatus(value); setPage(1); }}>{label}</button>
          ))}
        </div>
        <input className="input" placeholder="Buscar aluno" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} />
      </div>
      {!memberships.data ? <Loading /> : (
        <div className="table-wrap">
          {memberships.data.items.length === 0 ? <Empty title="Nenhuma matrícula" /> : (
            <table>
              <thead><tr><th>Aluno</th><th>Plano</th><th>Ciclo</th><th className="num">Valor</th><th>Início</th><th>Fim</th><th>Status</th></tr></thead>
              <tbody>
                {memberships.data.items.map((m) => (
                  <tr key={m.id}>
                    <td><Link className="row-link" to={`/alunos/${m.studentId}`}>{m.student?.name}</Link></td>
                    <td>{m.plan.name}</td>
                    <td className="muted">{CYCLE_LABEL[m.plan.billingCycleMonths ?? 1]}</td>
                    <td className="num mono">{formatMoney(m.priceCents)}</td>
                    <td>{formatDate(m.startDate)}</td>
                    <td>{formatDate(m.endDate)}</td>
                    <td><Badge tone={STATUS[m.status][0]}>{STATUS[m.status][1]}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <Pager page={page} pageSize={25} total={memberships.data.total} onPage={setPage} />
        </div>
      )}
      {creating && <MembershipForm onClose={() => setCreating(false)} />}
    </>
  );
}
