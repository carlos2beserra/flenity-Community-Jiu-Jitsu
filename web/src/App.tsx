import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { useAuth } from './lib/auth';
import { Layout } from './components/Layout';
import { Loading } from './components/ui';
import { CheckInPage } from './pages/CheckIn';
import { DashboardPage } from './pages/Dashboard';
import { FinancePage } from './pages/Finance';
import { GraduationsPage } from './pages/Graduations';
import { LeadsPage } from './pages/Leads';
import { LoginPage } from './pages/Login';
import { MembershipsPage } from './pages/Memberships';
import { ModalitiesPage } from './pages/Modalities';
import { PlansPage } from './pages/Plans';
import { SchedulePage } from './pages/Schedule';
import { StudentDetailPage } from './pages/StudentDetail';
import { StudentsPage } from './pages/Students';
import { CommunityInvitePage } from './pages/CommunityInvite';
import { TeamPage } from './pages/Team';

export function App() {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();
  if (location.pathname === '/convite') return <CommunityInvitePage />;
  if (!isAuthenticated) return <LoginPage />;
  if (isLoading) return <Loading />;

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<DashboardPage />} />
        <Route path="check-in" element={<CheckInPage />} />
        <Route path="agenda" element={<SchedulePage />} />
        <Route path="alunos" element={<StudentsPage />} />
        <Route path="alunos/:id" element={<StudentDetailPage />} />
        <Route path="graduacoes" element={<GraduationsPage />} />
        <Route path="crm" element={<LeadsPage />} />
        <Route path="financeiro" element={<FinancePage />} />
        <Route path="matriculas" element={<MembershipsPage />} />
        <Route path="planos" element={<PlansPage />} />
        <Route path="jiu-jitsu" element={<ModalitiesPage />} />
        <Route path="modalidades" element={<Navigate to="/jiu-jitsu" replace />} />
        <Route path="equipe" element={<TeamPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
