const MS_PER_DAY = 86_400_000;

/** Normaliza para meia-noite UTC (datas sem horário). */
export function toDateOnly(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

export function diffInDays(later: Date, earlier: Date): number {
  return Math.floor((toDateOnly(later).getTime() - toDateOnly(earlier).getTime()) / MS_PER_DAY);
}

/** Soma meses mantendo o dia, limitado ao último dia do mês (31/01 + 1 mês = 28/02). */
export function addMonths(date: Date, months: number): Date {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + months;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return new Date(Date.UTC(year, month, Math.min(date.getUTCDate(), lastDay)));
}

/** Início da semana (segunda-feira) em UTC. */
export function startOfWeek(date: Date): Date {
  const day = toDateOnly(date);
  const offset = (day.getUTCDay() + 6) % 7;
  return new Date(day.getTime() - offset * MS_PER_DAY);
}

export const APP_TIMEZONE = process.env.APP_TIMEZONE ?? 'America/Sao_Paulo';

/** Diferença (ms) entre o horário de parede no fuso e o UTC no instante dado. */
function tzOffsetMs(instant: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(instant);
  const get = (type: string) => Number(parts.find((p) => p.type === type)!.value);
  const wall = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour'), get('minute'), get('second'));
  return wall - Math.floor(instant.getTime() / 1000) * 1000;
}

/** Data de calendário atual no fuso da academia, como data-only (meia-noite UTC). */
export function zonedToday(now: Date = new Date(), timeZone = APP_TIMEZONE): Date {
  return toDateOnly(new Date(now.getTime() + tzOffsetMs(now, timeZone)));
}

/** Instante UTC da meia-noite local de uma data de calendário (data-only). */
export function zonedDayStart(localDate: Date, timeZone = APP_TIMEZONE): Date {
  const guess = toDateOnly(localDate).getTime();
  return new Date(guess - tzOffsetMs(new Date(guess), timeZone));
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * MS_PER_DAY);
}

/** Dia da semana (0 = domingo) e minutos desde a meia-noite no fuso da academia. */
export function zonedClock(now: Date = new Date(), timeZone = APP_TIMEZONE): { weekday: number; minutes: number } {
  const local = new Date(now.getTime() + tzOffsetMs(now, timeZone));
  return { weekday: local.getUTCDay(), minutes: local.getUTCHours() * 60 + local.getUTCMinutes() };
}
