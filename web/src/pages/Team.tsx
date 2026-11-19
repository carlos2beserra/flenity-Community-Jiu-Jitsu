import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Badge, Empty, errorMessage, Field, Loading, ModalForm, PageHeader, Person } from '../components/ui';
import { api } from '../lib/api';
import { ROLE_LABEL } from '../lib/format';
import { useAuth } from '../lib/auth';
import type { User } from '../lib/types';

type InstructorForm = { name: string; email: string; password: string };

export function TeamPage() {
  const { me } = useAuth();
  const queryClient = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [createdInstructor, setCreatedInstructor] = useState<string | null>(null);
  const [form, setForm] = useState<InstructorForm>({ name: '', email: '', password: '' });

  const users = useQuery({
    queryKey: ['team-users'],
    queryFn: () => api<User[]>('/users'),
    enabled: me?.role === 'ADMIN',
  });
  const createInstructor = useMutation({
    mutationFn: (input: InstructorForm) => api<User>('/users', {
      body: { ...input, role: 'INSTRUCTOR' },
    }),
    onSuccess: async (created) => {
      await queryClient.invalidateQueries({ queryKey: ['team-users'] });
      setCreatedInstructor(created.name);
      setForm({ name: '', email: '', password: '' });
      setCreating(false);
    },
  });

  if (me?.role !== 'ADMIN') {
    return (
      <>
        <PageHeader kicker="Administração" title="Equipe" />
        <div className="alert alert-bad">Somente administradores podem gerenciar a equipe.</div>
      </>
    );
  }

  const instructors = users.data?.filter((user) => user.role === 'INSTRUCTOR') ?? [];

  return (
    <>
      <PageHeader
        kicker="Administração"
        title="Equipe"
        actions={<button className="btn btn-primary" onClick={() => {
          setCreatedInstructor(null);
          setCreating(true);
        }}>+ Adicionar professor</button>}
      />
      <p className="muted" style={{ marginTop: -8, marginBottom: 20 }}>
        Crie acessos individuais para professores entrarem no app selecionando “Sou profissional”.
      </p>
      {createdInstructor && (
        <div className="alert alert-good" role="status" style={{ marginBottom: 16 }}>
          Acesso de {createdInstructor} criado. O professor já pode entrar no app com o e-mail e a senha inicial.
        </div>
      )}
      {users.isLoading ? <Loading /> : users.error ? (
        <div className="alert alert-bad">{errorMessage(users.error)}</div>
      ) : (
        <div className="table-wrap">
          {instructors.length === 0 ? (
            <Empty title="Nenhum professor cadastrado">
              Adicione um professor para liberar o acesso dele ao app mobile.
            </Empty>
          ) : (
            <table>
              <thead><tr><th>Professor</th><th>E-mail de acesso</th><th>Perfil</th></tr></thead>
              <tbody>
                {instructors.map((instructor) => (
                  <tr key={instructor.id}>
                    <td><Person name={instructor.name} /></td>
                    <td>{instructor.email}</td>
                    <td><Badge tone="neutral">{ROLE_LABEL[instructor.role]}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
      {creating && (
        <ModalForm
          title="Adicionar professor"
          submitLabel="Criar acesso"
          onClose={() => {
            if (!createInstructor.isPending) {
              setCreating(false);
              createInstructor.reset();
            }
          }}
          onSubmit={() => createInstructor.mutate(form)}
          pending={createInstructor.isPending}
          error={createInstructor.error}
        >
          <Field label="Nome completo" span>
            <input className="input" required minLength={2} autoFocus value={form.name}
              onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))} />
          </Field>
          <Field label="E-mail de acesso" span>
            <input className="input" type="email" required value={form.email}
              onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))} />
          </Field>
          <Field label="Senha inicial" span>
            <input className="input" type="password" required minLength={8} maxLength={128}
              autoComplete="new-password" value={form.password}
              onChange={(event) => setForm((current) => ({ ...current, password: event.target.value }))} />
          </Field>
          <p className="muted span-2" style={{ margin: 0, fontSize: 13 }}>
            Compartilhe as credenciais diretamente com o professor. A senha precisa ter pelo menos 8 caracteres.
          </p>
        </ModalForm>
      )}
    </>
  );
}
