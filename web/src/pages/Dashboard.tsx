import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { api } from '../lib/api';
import { formatDate, formatMoney } from '../lib/format';
import type { BoardRow, ClassSchedule, DashboardSummary } from '../lib/types';
import { BarChart } from '../components/BarChart';
import { BeltBadge } from '../components/BeltBadge';
import { Empty, Loading, PageHeader, Stat } from '../components/ui';

const WEEKDAY_SHORT = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
const MONTH_SHORT = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
const compactMoney = (cents: number) => (cents >= 100_000 ? `${Math.round(cents / 100_000)}k` : String(Math.round(cents / 100)));

export function DashboardPage() {
  const summary = useQuery({ queryKey: ['dashboard'], queryFn: () => api<DashboardSummary>('/dashboard') });
  const today = useQuery({ queryKey: ['classes', 'today'], queryFn: () => api<ClassSchedule[]>('/classes/today') });
  const eligible = useQuery({ queryKey: ['graduations', 'eligible'], queryFn: () => api<BoardRow[]>('/graduations?eligibleOnly=true') });
  const birthdays = useQuery({
    queryKey: ['birthdays'],
    queryFn: () => api<{ id: string; name: string; birthDate: string }[]>('/dashboard/birthdays'),
  });

  if (!summary.data) return <Loading />;
  const s = summary.data;
  const collected = s.expectedThisMonthCents ? Math.round((s.revenueThisMonthCents / s.expectedThisMonthCents) * 100) : 0;

  return (
    <>
      <PageHeader kicker={new Date().toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' })} title="Painel Jiu-Jitsu"
        actions={<Link to="/check-in" className="btn btn-primary">Registrar acesso</Link>} />
      <section className="bjj-spotlight">
        <div>
          <span className="bjj-kicker">GESTÃO DE JIU-JITSU</span>
          <h2>Uma academia. Uma arte. Muitas jornadas.</h2>
          <p>Organize aulas, graduações e a evolução de cada faixa da sua comunidade.</p>
        </div>
        <nav className="bjj-links" aria-label="Atalhos de Jiu-Jitsu">
          <Link to="/agenda"><span>01</span>Agenda de aulas <b>↗</b></Link>
          <Link to="/jiu-jitsu"><span>02</span>Faixas e graduações <b>↗</b></Link>
        </nav>
      </section>

      <div className="grid grid-4 reveal" style={{ marginBottom: 16 }}>
        <Stat hot label="Alunos ativos" value={s.activeStudents} sub={`${s.activeMemberships} matrículas ativas`} />
        <Stat label="Receita recorrente (MRR)" value={formatMoney(s.mrrCents)} sub="Normalizada por mês" />
        <Stat label="Recebido no mês" value={formatMoney(s.revenueThisMonthCents)} sub={`${collected}% de ${formatMoney(s.expectedThisMonthCents)} previsto`} />
        <Stat label="Inadimplência" value={formatMoney(s.overdueCents)}
          sub={<Link to="/financeiro?status=OVERDUE">{s.overdueCount} cobrança(s) vencida(s) →</Link>} />
      </div>

      <div className="grid grid-main" style={{ marginBottom: 16 }}>
        <div className="card">
          <h2 className="card-title">Check-ins — últimos 7 dias <small>{s.checkInsToday} hoje</small></h2>
          <BarChart ariaLabel="Check-ins por dia nos últimos 7 dias"
            data={s.checkInsByDay.map((d) => ({
              label: `${WEEKDAY_SHORT[new Date(`${d.day}T12:00:00Z`).getUTCDay()]} ${d.day.slice(8)}`,
              value: d.total,
              tooltip: `${d.total} check-in(s)`,
            }))} />
        </div>
        <div className="card">
          <h2 className="card-title">Aulas de hoje</h2>
          {today.data?.length ? (
            <ul className="timeline">
              {today.data.map((c) => (
                <li key={c.id}>
                  <span>
                    <span className="mono muted">{c.startTime}</span> <strong>{c.name}</strong>
                    <span className="muted" style={{ display: 'block', fontSize: 12 }}>{c.instructor?.name ?? 'Sem instrutor'}</span>
                  </span>
                  <span className="mono">{c.checkInsToday}/{c.capacity}</span>
                </li>
              ))}
            </ul>
          ) : <Empty title="Agenda livre">Nenhuma aula de Jiu-Jitsu programada para hoje.</Empty>}
        </div>
      </div>

      <div className="grid grid-3">
        <div className="card">
          <h2 className="card-title">Receita recebida <small>6 meses</small></h2>
          <BarChart ariaLabel="Receita recebida por mês" height={160} formatAxis={compactMoney}
            data={s.revenueByMonth.map((r) => ({
              label: MONTH_SHORT[Number(r.month.slice(5)) - 1],
              value: r.totalCents,
              tooltip: formatMoney(r.totalCents),
            }))} />
        </div>
        <div className="card">
          <h2 className="card-title">Jiu-Jitsu <small>check-ins no mês</small></h2>
          {s.modalityMix.length ? (
            <div className="hbars">
              {s.modalityMix.map((m) => (
                <div className="hbar-row" key={m.modality}>
                  <span>{m.modality}</span>
                  <div className="hbar-track"><div className="hbar-fill" style={{ width: `${(m.total / s.modalityMix[0].total) * 100}%` }} /></div>
                  <span className="num">{m.total}</span>
                </div>
              ))}
            </div>
          ) : <Empty title="Sem check-ins ainda" />}
        </div>
        <div className="card">
          <h2 className="card-title">Evolução nas lutas <small><Link to="/graduacoes">ver graduações →</Link></small></h2>
          {eligible.data?.length ? (
            <ul className="timeline">
              {eligible.data.slice(0, 5).map((r) => (
                <li key={`${r.studentId}-${r.modalityId}`}>
                  <Link className="row-link" to={`/alunos/${r.studentId}`}>{r.studentName}</Link>
                  <BeltBadge name={r.beltName} color={r.beltColor} degree={r.degree} showLabel={false} />
                </li>
              ))}
            </ul>
          ) : <Empty title="Ninguém apto" />}
          {!!birthdays.data?.length && (
            <>
              <h2 className="card-title" style={{ marginTop: 18 }}>Aniversariantes do mês</h2>
              <ul className="timeline">
                {birthdays.data.slice(0, 5).map((b) => (
                  <li key={b.id}><Link className="row-link" to={`/alunos/${b.id}`}>{b.name}</Link><span className="mono muted">{formatDate(b.birthDate).slice(0, 5)}</span></li>
                ))}
              </ul>
            </>
          )}
        </div>
      </div>
    </>
  );
}
