import { isSelfCheckInOpen } from './self-checkin';

const slot = { weekday: 1, startTime: '19:30', endTime: '21:00' };
const at = (weekday: number, hhmm: string) => {
  const [h, m] = hhmm.split(':').map(Number);
  return { weekday, minutes: h * 60 + m };
};

describe('isSelfCheckInOpen', () => {
  it('abre 30 minutos antes do início', () => {
    expect(isSelfCheckInOpen(slot, at(1, '18:59'))).toBe(false);
    expect(isSelfCheckInOpen(slot, at(1, '19:00'))).toBe(true);
  });

  it('fica aberto até o fim da aula', () => {
    expect(isSelfCheckInOpen(slot, at(1, '21:00'))).toBe(true);
    expect(isSelfCheckInOpen(slot, at(1, '21:01'))).toBe(false);
  });

  it('só vale no dia da semana da turma', () => {
    expect(isSelfCheckInOpen(slot, at(2, '19:45'))).toBe(false);
  });
});
