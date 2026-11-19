const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

export const formatMoney = (cents: number) => currency.format(cents / 100);

/** Converte "220,50" ou "220.50" em centavos. */
export function parseMoney(input: string): number {
  const normalized = input.replace(/[^\d,.-]/g, '').replace(/\.(?=\d{3}(\D|$))/g, '').replace(',', '.');
  const value = /\d/.test(normalized) ? Number(normalized) : NaN;
  return Number.isFinite(value) ? Math.round(value * 100) : NaN;
}

/** Datas "date-only" chegam como meia-noite UTC: formatar em UTC evita voltar um dia. */
export const formatDate = (iso: string | null | undefined) =>
  iso ? new Date(iso).toLocaleDateString('pt-BR', { timeZone: 'UTC' }) : '—';

export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });

export const formatTime = (iso: string) => new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

/** Data local (não UTC) no formato YYYY-MM-DD. */
export const todayIso = () => new Date().toLocaleDateString('en-CA');

export const WEEKDAYS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

export const CYCLE_LABEL: Record<number, string> = { 1: 'Mensal', 3: 'Trimestral', 6: 'Semestral', 12: 'Anual' };

export const PAYMENT_LABEL: Record<string, string> = {
  PIX: 'Pix', CASH: 'Dinheiro', CREDIT_CARD: 'Crédito', DEBIT_CARD: 'Débito', BOLETO: 'Boleto',
};

export const STUDENT_STATUS: Record<string, string> = { ACTIVE: 'Ativo', INACTIVE: 'Inativo', SUSPENDED: 'Suspenso' };

export const ROLE_LABEL: Record<string, string> = { ADMIN: 'Administrador', INSTRUCTOR: 'Instrutor', RECEPTION: 'Recepção' };

export function invoiceState(invoice: { status: string; dueDate: string }): 'PAID' | 'CANCELED' | 'OVERDUE' | 'PENDING' {
  if (invoice.status !== 'PENDING') return invoice.status as 'PAID' | 'CANCELED';
  return invoice.dueDate.slice(0, 10) < todayIso() ? 'OVERDUE' : 'PENDING';
}

export const INVOICE_STATE_LABEL = { PAID: 'Pago', CANCELED: 'Cancelado', OVERDUE: 'Vencido', PENDING: 'A vencer' };

export const initials = (name: string) =>
  name.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]!.toUpperCase()).join('');
