import { daysOverdue, dueDateInMonth, isOverdue } from './billing';

const d = (iso: string) => new Date(`${iso}T00:00:00Z`);

describe('dueDateInMonth', () => {
  it('cobra todo mês no mesmo dia para plano mensal', () => {
    // Arrange
    const membership = { startDate: d('2026-01-15'), endDate: null, billingCycleMonths: 1 };
    // Act
    const due = dueDateInMonth(membership, 2026, 4);
    // Assert
    expect(due).toEqual(d('2026-05-15'));
  });

  it('ajusta para o último dia em meses mais curtos', () => {
    const membership = { startDate: d('2026-01-31'), endDate: null, billingCycleMonths: 1 };
    expect(dueDateInMonth(membership, 2026, 1)).toEqual(d('2026-02-28'));
  });

  it('cobra apenas a cada 3 meses no plano trimestral', () => {
    const membership = { startDate: d('2026-01-10'), endDate: null, billingCycleMonths: 3 };
    expect(dueDateInMonth(membership, 2026, 1)).toBeNull();
    expect(dueDateInMonth(membership, 2026, 3)).toEqual(d('2026-04-10'));
  });

  it('não cobra antes do início nem depois do fim do contrato', () => {
    const membership = { startDate: d('2026-03-05'), endDate: d('2026-05-01'), billingCycleMonths: 1 };
    expect(dueDateInMonth(membership, 2026, 1)).toBeNull();
    expect(dueDateInMonth(membership, 2026, 4)).toBeNull();
  });
});

describe('daysOverdue', () => {
  it('conta dias de atraso de fatura pendente', () => {
    expect(daysOverdue({ status: 'PENDING', dueDate: d('2026-10-01') }, d('2026-10-11'))).toBe(10);
  });

  it('retorna zero para fatura paga ou ainda não vencida', () => {
    expect(daysOverdue({ status: 'PAID', dueDate: d('2026-01-01') }, d('2026-10-11'))).toBe(0);
    expect(isOverdue({ status: 'PENDING', dueDate: d('2026-10-20') }, d('2026-10-11'))).toBe(false);
  });
});
