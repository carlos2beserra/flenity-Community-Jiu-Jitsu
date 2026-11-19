import { PaymentMethod, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { zonedDayStart, zonedToday } from '../src/domain/dates';
import { starterFor, TRACK_CATEGORIES } from '../src/domain/tracks';

const prisma = new PrismaClient();
const DAY_MS = 86_400_000;
const DEMO_EMAIL = 'admin@flenity.com';

// Gerador determinístico para o seed ser reprodutível.
let seed = 42;
const random = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
const pick = <T>(items: T[]): T => items[Math.floor(random() * items.length)];
const dateOnly = (d: Date) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));

const MODALITIES = [
  {
    name: 'Jiu-Jitsu',
    belts: [
      ['Branca', '#f5f5f5', 40], ['Azul', '#1e5bd6', 120], ['Roxa', '#7b2fbf', 150],
      ['Marrom', '#7a4a21', 150], ['Preta', '#111111', 300],
    ],
  },
] as const;

const FIRST_NAMES = ['Lucas', 'Mariana', 'Rafael', 'Juliana', 'Pedro', 'Camila', 'Thiago', 'Beatriz', 'Gabriel', 'Larissa',
  'Bruno', 'Fernanda', 'Diego', 'Amanda', 'Matheus', 'Letícia', 'Felipe', 'Isabela', 'Gustavo', 'Natália',
  'Rodrigo', 'Carolina', 'Vinícius', 'Patrícia', 'André', 'Aline', 'Leonardo', 'Bianca', 'Eduardo', 'Renata'];
const LAST_NAMES = ['Silva', 'Santos', 'Oliveira', 'Souza', 'Lima', 'Pereira', 'Costa', 'Ferreira', 'Almeida', 'Gracie',
  'Machado', 'Ribeiro', 'Carvalho', 'Gomes', 'Barbosa'];

async function main() {
  const existing = await prisma.user.findUnique({ where: { email: DEMO_EMAIL } });
  if (existing) await prisma.academy.delete({ where: { id: existing.academyId } });

  const today = zonedToday();
  const academy = await prisma.academy.create({ data: { name: 'Flenity Jiu-Jitsu - Unidade Centro' } });
  const passwordHash = await bcrypt.hash('combate123', 10);
  const admin = await prisma.user.create({
    data: { academyId: academy.id, name: 'Carlos Admin', email: DEMO_EMAIL, passwordHash, role: 'ADMIN' },
  });
  const instructors = await Promise.all(
    ['Mestre Renzo', 'Professor Bruno', 'Professora Marina', 'Professor Rafael'].map((name, i) =>
      prisma.user.create({
        data: { academyId: academy.id, name, email: `instrutor${i + 1}@flenity.com`, passwordHash, role: 'INSTRUCTOR' },
      }),
    ),
  );
  await prisma.user.create({
    data: { academyId: academy.id, name: 'Recepção', email: 'recepcao@flenity.com', passwordHash, role: 'RECEPTION' },
  });

  const modalities = [];
  for (const m of MODALITIES) {
    modalities.push(
      await prisma.modality.create({
        data: {
          academyId: academy.id,
          name: m.name,
          belts: { create: m.belts.map(([name, color, minClasses], order) => ({ name, color, minClasses, order })) },
        },
        include: { belts: { orderBy: { order: 'asc' } } },
      }),
    );
  }
  const [bjj] = modalities;

  // Trilhas "Descomplicando": sugestão para todas as faixas como rascunho (o professor grava os vídeos e libera).
  await prisma.trackLesson.createMany({
    data: bjj.belts.flatMap((belt) =>
      TRACK_CATEGORIES.flatMap((category) =>
        starterFor(belt.order)[category].map((lesson, position) => ({
          academyId: academy.id, beltId: belt.id, category, position, ...lesson,
        })),
      ),
    ),
  });

  const plans = await Promise.all([
    createPlan(academy.id, 'Jiu-Jitsu Mensal', 22000, 1, null, [bjj.id]),
    createPlan(academy.id, 'Jiu-Jitsu 2x por semana', 16000, 1, 2, [bjj.id]),
    createPlan(academy.id, 'Jiu-Jitsu Trimestral', 62000, 3, null, [bjj.id]),
    createPlan(academy.id, 'Jiu-Jitsu Semestral', 120000, 6, null, [bjj.id]),
    createPlan(academy.id, 'Jiu-Jitsu Kids', 18000, 1, null, [bjj.id]),
    createPlan(academy.id, 'Jiu-Jitsu Livre', 24000, 1, null, [bjj.id]),
  ]);

  // Agenda semanal
  const schedule: [typeof bjj, number, string, string, string, number][] = [
    [bjj, 1, 'Jiu-Jitsu Fundamentos', '07:00', '08:00', 0], [bjj, 3, 'Jiu-Jitsu Fundamentos', '07:00', '08:00', 0],
    [bjj, 1, 'Jiu-Jitsu Avançado', '19:30', '21:00', 0], [bjj, 2, 'Jiu-Jitsu No-Gi', '19:30', '21:00', 0],
    [bjj, 4, 'Jiu-Jitsu Avançado', '19:30', '21:00', 0], [bjj, 6, 'Open Mat', '10:00', '12:00', 0],
  ];
  const classes = await Promise.all(
    schedule.map(([modality, weekday, name, startTime, endTime, instructorIdx]) =>
      prisma.classSchedule.create({
        data: { academyId: academy.id, modalityId: modality.id, instructorId: instructors[instructorIdx].id, name, weekday, startTime, endTime, capacity: 30 },
      }),
    ),
  );

  // Alunos, matrículas, mensalidades, graduações e presenças
  for (let i = 0; i < 48; i++) {
    const name = `${FIRST_NAMES[i % FIRST_NAMES.length]} ${pick(LAST_NAMES)}`;
    const startDate = dateOnly(new Date(today.getTime() - Math.floor(random() * 420 + 5) * DAY_MS));
    const inactive = i % 13 === 12;
    const email = i === 0 ? 'aluno@flenity.com' : `${name.toLowerCase().normalize('NFD').replace(/[^a-z ]/g, '').replace(' ', '.')}${i}@email.com`;
    const student = await prisma.student.create({
      data: {
        academy: { connect: { id: academy.id } },
        account: { create: { email, passwordHash: i === 0 ? passwordHash : null } },
        name,
        // O primeiro aluno é a conta de demonstração do app (aluno@flenity.com / combate123).
        email,
        passwordHash: i === 0 ? passwordHash : null,
        phone: `(11) 9${String(80000000 + Math.floor(random() * 19999999))}`,
        birthDate: new Date(Date.UTC(1975 + Math.floor(random() * 35), Math.floor(random() * 12), 1 + Math.floor(random() * 28))),
        status: inactive ? 'INACTIVE' : 'ACTIVE',
        createdAt: startDate,
      },
    });
    if (inactive) continue;

    const plan = pick(plans);
    const membership = await prisma.membership.create({
      data: { academyId: academy.id, studentId: student.id, planId: plan.id, priceCents: plan.priceCents, startDate },
    });

    // Mensalidades desde o início; a maioria paga, algumas em atraso.
    const isDebtor = i % 7 === 3;
    for (let cycle = 0; ; cycle += plan.billingCycleMonths) {
      const due = new Date(Date.UTC(startDate.getUTCFullYear(), startDate.getUTCMonth() + cycle, Math.min(startDate.getUTCDate(), 28)));
      if (due > new Date(today.getTime() + 20 * DAY_MS)) break;
      const recent = today.getTime() - due.getTime() < 40 * DAY_MS;
      const paid = due <= today && !(isDebtor && recent);
      await prisma.invoice.create({
        data: {
          academyId: academy.id,
          studentId: student.id,
          membershipId: membership.id,
          description: `${plan.name} - ${String(due.getUTCMonth() + 1).padStart(2, '0')}/${due.getUTCFullYear()}`,
          amountCents: plan.priceCents,
          dueDate: due,
          status: paid ? 'PAID' : 'PENDING',
          paidAt: paid ? new Date(due.getTime() + Math.floor(random() * 5) * DAY_MS) : null,
          paymentMethod: paid ? pick<PaymentMethod>(['PIX', 'PIX', 'PIX', 'CREDIT_CARD', 'CASH', 'DEBIT_CARD']) : null,
        },
      });
    }

    for (const { modality } of plan.modalities) {
      const belts = modalities.find((m) => m.id === modality.id)!.belts;
      const beltIndex = Math.min(belts.length - 1, Math.floor(random() * random() * belts.length));
      const promotedAt = new Date(startDate.getTime() + Math.floor(random() * 30) * DAY_MS);
      await prisma.studentRank.create({
        data: {
          studentId: student.id,
          modalityId: modality.id,
          beltId: belts[beltIndex].id,
          degree: Math.floor(random() * 4),
          promotedAt: promotedAt > today ? startDate : promotedAt,
        },
      });

      const modalityClasses = classes.filter((c) => c.modalityId === modality.id);
      const frequency = 0.15 + random() * 0.55;
      const firstDay = Math.max(startDate.getTime(), today.getTime() - 180 * DAY_MS);
      const checkIns = [];
      for (let t = firstDay; t <= today.getTime(); t += DAY_MS) {
        const day = new Date(t);
        for (const cls of modalityClasses.filter((c) => c.weekday === day.getUTCDay())) {
          if (random() > frequency) continue;
          const [h, min] = cls.startTime.split(':').map(Number);
          checkIns.push({
            academyId: academy.id, studentId: student.id, modalityId: modality.id, classId: cls.id,
            checkedAt: new Date(zonedDayStart(day).getTime() + (h * 60 + min - 10) * 60_000),
          });
        }
      }
      await prisma.checkIn.createMany({ data: checkIns.filter((c) => c.checkedAt <= new Date()) });
    }
  }

  const leadData: [string, string, string, 'NEW' | 'CONTACTED' | 'TRIAL' | 'CONVERTED' | 'LOST'][] = [
    ['Joana Prado', 'Instagram', 'Jiu-Jitsu', 'NEW'], ['Ricardo Nunes', 'Indicação', 'Jiu-Jitsu', 'NEW'],
    ['Paula Mendes', 'Google', 'Jiu-Jitsu', 'CONTACTED'], ['Marcos Vieira', 'Fachada', 'Jiu-Jitsu', 'TRIAL'],
    ['Sofia Rocha', 'Instagram', 'Jiu-Jitsu Kids', 'TRIAL'], ['Henrique Dias', 'Indicação', 'Jiu-Jitsu', 'CONTACTED'],
    ['Clara Moura', 'Google', 'Jiu-Jitsu', 'LOST'], ['Otávio Reis', 'Instagram', 'Jiu-Jitsu', 'NEW'],
  ];
  await prisma.lead.createMany({
    data: leadData.map(([name, source, interest, status]) => ({
      academyId: academy.id, name, source, interest, status, phone: '(11) 98888-0000',
    })),
  });

  console.log(`Seed concluído. Web: ${admin.email} / combate123 · App do aluno: aluno@flenity.com / combate123`);
}

function createPlan(academyId: string, name: string, priceCents: number, billingCycleMonths: number, weeklyLimit: number | null, modalityIds: string[]) {
  return prisma.plan.create({
    data: { academyId, name, priceCents, billingCycleMonths, weeklyLimit, modalities: { create: modalityIds.map((modalityId) => ({ modalityId })) } },
    include: { modalities: { include: { modality: true } } },
  });
}

main()
  .catch((error) => {
    console.error('Falha no seed', error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
