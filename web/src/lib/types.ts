export type Role = 'ADMIN' | 'INSTRUCTOR' | 'RECEPTION';
export type User = { id: string; name: string; email: string; role: Role };
export type Me = User & { academy: { id: string; name: string; blockOverdueDays: number } };

export type Belt = { id: string; name: string; color: string; order: number; minClasses: number; maxDegrees: number };
export type Modality = { id: string; name: string; belts: Belt[] };

export type Student = {
  id: string; name: string; email: string | null; phone: string | null; cpf: string | null;
  birthDate: string | null; status: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED'; notes: string | null; createdAt: string;
};

export type Plan = {
  id: string; name: string; priceCents: number; billingCycleMonths: number; weeklyLimit: number | null; active: boolean;
  modalities: { modality: { id: string; name: string } }[];
};

export type Invoice = {
  id: string; studentId: string; membershipId: string | null; description: string; amountCents: number;
  dueDate: string; status: 'PENDING' | 'PAID' | 'CANCELED'; paidAt: string | null; paymentMethod: string | null;
  student?: { id: string; name: string; phone: string | null };
};

export type Membership = {
  id: string; studentId: string; planId: string; priceCents: number; startDate: string; endDate: string | null;
  status: 'ACTIVE' | 'CANCELED' | 'EXPIRED';
  plan: { id: string; name: string; billingCycleMonths?: number };
  student?: { id: string; name: string };
};

export type Rank = { id: string; degree: number; promotedAt: string; belt: Belt; modality: { id: string; name: string } };

export type StudentDetail = Student & {
  hasAppAccess: boolean;
  memberships: Membership[];
  invoices: Invoice[];
  ranks: Rank[];
  checkIns: { id: string; checkedAt: string; modality: { id: string; name: string } }[];
};

export type ClassSchedule = {
  id: string; name: string; weekday: number; startTime: string; endTime: string; capacity: number;
  modality: { id: string; name: string }; instructor: { id: string; name: string } | null; checkInsToday?: number;
};

export type CheckIn = {
  id: string; checkedAt: string; student: { id: string; name: string }; modality: { id: string; name: string };
  class: { id: string; name: string; startTime: string } | null;
};

export type BoardRow = {
  studentId: string; studentName: string; modalityId: string; modalityName: string; beltId: string; beltName: string;
  beltColor: string; degree: number; maxDegrees: number; minClasses: number; promotedAt: string; classesSince: number; eligible: boolean;
};

export type LeadStatus = 'NEW' | 'CONTACTED' | 'TRIAL' | 'CONVERTED' | 'LOST';
export type Lead = {
  id: string; name: string; phone: string | null; email: string | null; source: string | null; interest: string | null;
  status: LeadStatus; notes: string | null; createdAt: string;
};

export type DashboardSummary = {
  activeStudents: number; activeMemberships: number; mrrCents: number; revenueThisMonthCents: number;
  expectedThisMonthCents: number; overdueCents: number; overdueCount: number; checkInsToday: number; leadsOpen: number;
  checkInsByDay: { day: string; total: number }[];
  revenueByMonth: { month: string; totalCents: number }[];
  modalityMix: { modality: string; total: number }[];
};
