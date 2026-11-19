import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../lib/auth';
import { ROLE_LABEL } from '../lib/format';

const icon = (d: string) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <path d={d} />
  </svg>
);

const SECTIONS = [
  {
    label: 'Aulas',
    links: [
      { to: '/', label: 'Painel', icon: icon('M3 13h8V3H3zM13 21h8V11h-8zM3 21h8v-6H3zM13 3v6h8V3z') },
      { to: '/check-in', label: 'Acesso', icon: icon('M9 11l3 3 8-8M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9') },
      { to: '/agenda', label: 'Agenda', icon: icon('M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z') },
      { to: '/jiu-jitsu', label: 'Jiu-Jitsu', icon: icon('M12 2l3 7h7l-5.5 4.5 2 7.5L12 16.5 5.5 21l2-7.5L2 9h7z') },
    ],
  },
  {
    label: 'Pessoas',
    links: [
      { to: '/alunos', label: 'Alunos', icon: icon('M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75') },
      { to: '/crm', label: 'CRM / Leads', icon: icon('M22 12h-4l-3 9L9 3l-3 9H2') },
    ],
  },
  {
    label: 'Jiu-Jitsu',
    links: [
      { to: '/graduacoes', label: 'Graduações de luta', icon: icon('M2 12h20M2 12l3-3M2 12l3 3M15 9h4v6h-4z') },
    ],
  },
  {
    label: 'Gestão',
    links: [
      { to: '/financeiro', label: 'Financeiro', icon: icon('M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6') },
      { to: '/matriculas', label: 'Matrículas', icon: icon('M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6M9 15l2 2 4-4') },
      { to: '/planos', label: 'Planos', icon: icon('M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82zM7 7h.01') },
    ],
  },
];

export function Layout() {
  const { me, logout } = useAuth();
  return (
    <div className="shell">
      <aside className="sidebar">
        <NavLink to="/" className="brand" aria-label="Flenity — Jiu-Jitsu Community — início">
          <span className="brand-word">Flenity</span>
          <span className="brand-tagline">Jiu-Jitsu Community</span>
          <span className="brand-belt" />
        </NavLink>
        <nav className="nav">
          {SECTIONS.map((section) => (
            <div key={section.label} style={{ display: 'contents' }}>
              <div className="nav-label">{section.label}</div>
              {section.links.map((link) => (
                <NavLink key={link.to} to={link.to} end={link.to === '/'}>
                  {link.icon}
                  {link.label}
                </NavLink>
              ))}
            </div>
          ))}
          {me?.role === 'ADMIN' && (
            <>
              <div className="nav-label">Administração</div>
              <NavLink to="/equipe">
                {icon('M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM19 8v6M22 11h-6')}
                Equipe
              </NavLink>
            </>
          )}
        </nav>
        <div className="sidebar-foot">
          <strong>{me?.name ?? '—'}</strong>
          <span>{me ? `${ROLE_LABEL[me.role]} · ${me.academy.name}` : ''}</span>
          <button className="btn btn-sm btn-ghost" onClick={logout}>Sair</button>
        </div>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
