import { CheckInContext, evaluateCheckIn } from './checkin-policy';

const today = new Date('2026-10-20T00:00:00Z');

function buildContext(overrides: Partial<CheckInContext> = {}): CheckInContext {
  return {
    studentStatus: 'ACTIVE',
    modalityId: 'bjj',
    activeMemberships: [{ modalityIds: ['bjj'], weeklyLimit: null }],
    pendingInvoices: [],
    blockOverdueDays: 10,
    checkInsThisWeek: 0,
    today,
    ...overrides,
  };
}

describe('evaluateCheckIn', () => {
  it('libera aluno ativo, adimplente e com plano da modalidade', () => {
    expect(evaluateCheckIn(buildContext())).toEqual({ allowed: true });
  });

  it('bloqueia aluno inativo', () => {
    const result = evaluateCheckIn(buildContext({ studentStatus: 'SUSPENDED' }));
    expect(result.allowed).toBe(false);
  });

  it('bloqueia quando o plano não cobre a modalidade', () => {
    const result = evaluateCheckIn(buildContext({ modalityId: 'muay-thai' }));
    expect(result).toEqual({ allowed: false, reason: 'Nenhum plano ativo cobre esta modalidade' });
  });

  it('tolera atraso dentro da carência e bloqueia acima dela', () => {
    const withinGrace = buildContext({ pendingInvoices: [{ status: 'PENDING', dueDate: new Date('2026-10-12T00:00:00Z') }] });
    const beyondGrace = buildContext({ pendingInvoices: [{ status: 'PENDING', dueDate: new Date('2026-10-01T00:00:00Z') }] });

    expect(evaluateCheckIn(withinGrace).allowed).toBe(true);
    expect(evaluateCheckIn(beyondGrace)).toEqual({ allowed: false, reason: 'Mensalidade em atraso há 19 dias' });
  });

  it('aplica o limite semanal do plano', () => {
    const ctx = buildContext({ activeMemberships: [{ modalityIds: ['bjj'], weeklyLimit: 2 }], checkInsThisWeek: 2 });
    expect(evaluateCheckIn(ctx)).toEqual({ allowed: false, reason: 'Limite semanal de 2 aulas atingido' });
  });

  it('ignora limite quando algum plano da modalidade é livre', () => {
    const ctx = buildContext({
      activeMemberships: [
        { modalityIds: ['bjj'], weeklyLimit: 2 },
        { modalityIds: ['bjj'], weeklyLimit: null },
      ],
      checkInsThisWeek: 5,
    });
    expect(evaluateCheckIn(ctx).allowed).toBe(true);
  });
});
