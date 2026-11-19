import { addMonths, startOfWeek, zonedClock, zonedDayStart, zonedToday } from './dates';

describe('zonedToday', () => {
  it('usa a data local de São Paulo, não a UTC', () => {
    // 23:30 em São Paulo de 20/10 = 02:30 UTC de 21/10
    const now = new Date('2026-10-21T02:30:00Z');
    expect(zonedToday(now, 'America/Sao_Paulo')).toEqual(new Date('2026-10-20T00:00:00Z'));
  });
});

describe('zonedDayStart', () => {
  it('converte meia-noite local para o instante UTC', () => {
    expect(zonedDayStart(new Date('2026-10-20T00:00:00Z'), 'America/Sao_Paulo')).toEqual(new Date('2026-10-20T03:00:00Z'));
  });
});

describe('startOfWeek / addMonths', () => {
  it('semana começa na segunda-feira', () => {
    expect(startOfWeek(new Date('2026-10-25T00:00:00Z'))).toEqual(new Date('2026-10-19T00:00:00Z'));
  });

  it('limita ao último dia do mês', () => {
    expect(addMonths(new Date('2026-01-31T00:00:00Z'), 1)).toEqual(new Date('2026-02-28T00:00:00Z'));
  });
});

describe('zonedClock', () => {
  it('retorna dia da semana e minutos locais de São Paulo', () => {
    // 2026-10-20T01:15Z = segunda 19/10 às 22:15 em São Paulo
    expect(zonedClock(new Date('2026-10-20T01:15:00Z'), 'America/Sao_Paulo')).toEqual({ weekday: 1, minutes: 22 * 60 + 15 });
  });
});
