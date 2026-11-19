import { describe, expect, it, vi } from 'vitest';
import { formatDate, invoiceState, parseMoney } from './format';

describe('parseMoney', () => {
  it('aceita formatos brasileiros e internacionais', () => {
    expect(parseMoney('220,50')).toBe(22050);
    expect(parseMoney('R$ 1.250,00')).toBe(125000);
    expect(parseMoney('99.9')).toBe(9990);
  });

  it('retorna NaN para texto inválido', () => {
    expect(parseMoney('abc')).toBeNaN();
  });
});

describe('formatDate', () => {
  it('não volta um dia em datas UTC à meia-noite', () => {
    expect(formatDate('2026-10-01T00:00:00.000Z')).toBe('01/10/2026');
  });
});

describe('invoiceState', () => {
  it('marca como vencida a cobrança pendente com vencimento passado', () => {
    // Arrange
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-20T12:00:00Z'));
    // Act / Assert
    expect(invoiceState({ status: 'PENDING', dueDate: '2026-10-19T00:00:00Z' })).toBe('OVERDUE');
    expect(invoiceState({ status: 'PENDING', dueDate: '2026-10-20T00:00:00Z' })).toBe('PENDING');
    expect(invoiceState({ status: 'PAID', dueDate: '2026-01-01T00:00:00Z' })).toBe('PAID');
    vi.useRealTimers();
  });
});
