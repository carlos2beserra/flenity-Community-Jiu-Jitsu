/** Minutos antes do início em que o aluno já pode fazer check-in pelo app. */
export const SELF_CHECKIN_OPENS_BEFORE_MIN = 30;

export type ClassSlot = { weekday: number; startTime: string; endTime: string };

export function toMinutes(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

/** O aluno pode fazer check-in de 30 min antes do início até o fim da aula, no dia da turma. */
export function isSelfCheckInOpen(slot: ClassSlot, clock: { weekday: number; minutes: number }): boolean {
  if (slot.weekday !== clock.weekday) return false;
  const opensAt = toMinutes(slot.startTime) - SELF_CHECKIN_OPENS_BEFORE_MIN;
  return clock.minutes >= opensAt && clock.minutes <= toMinutes(slot.endTime);
}
