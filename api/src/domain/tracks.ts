/**
 * Trilhas "Descomplicando a Faixa X": conceitos que o aluno precisa aprender em cada faixa,
 * separados em Guarda, Passagem, Controle e Finalizações. O professor cadastra e libera;
 * o aluno vê o que foi liberado para a faixa dele (e para as anteriores, como revisão).
 */
export const TRACK_CATEGORIES = ['GUARD', 'PASS', 'CONTROL', 'SUBMISSION'] as const;
export type TrackCategoryKey = (typeof TRACK_CATEGORIES)[number];

export const TRACK_CATEGORY_LABELS: Record<TrackCategoryKey, string> = {
  GUARD: 'Guarda',
  PASS: 'Passagem',
  CONTROL: 'Controle',
  SUBMISSION: 'Finalizações',
};

/** "Branca" → "Faixa Branca"; nomes que já começam com "Faixa" ficam como estão. */
export function beltTitle(name: string): string {
  const trimmed = name.trim();
  return /^faixa\b/i.test(trimmed) ? trimmed : `Faixa ${trimmed}`;
}

/** Aluno vê a faixa atual e as anteriores (revisão); faixas acima ficam bloqueadas. */
export function canStudentSeeBelt(beltOrder: number, currentOrder: number): boolean {
  return beltOrder <= currentOrder;
}

export type ProgressSummary = { completed: number; total: number; percent: number };

export function summarizeProgress(lessonIds: string[], completedIds: ReadonlySet<string>): ProgressSummary {
  const total = lessonIds.length;
  const completed = lessonIds.filter((id) => completedIds.has(id)).length;
  return { completed, total, percent: total === 0 ? 0 : Math.round((completed / total) * 100) };
}

/**
 * Move uma lição para cima/baixo trocando com a vizinha. Retorna as posições a gravar
 * ([id, posição]) já normalizadas 0..n-1, ou [] se não houver vizinha.
 */
export function swapPositions(
  ordered: { id: string; position: number }[],
  lessonId: string,
  direction: 'up' | 'down',
): [string, number][] {
  const index = ordered.findIndex((item) => item.id === lessonId);
  const neighbor = index + (direction === 'up' ? -1 : 1);
  if (index < 0 || neighbor < 0 || neighbor >= ordered.length) return [];
  const next = [...ordered];
  [next[index], next[neighbor]] = [next[neighbor], next[index]];
  return next.flatMap((item, position): [string, number][] => (item.position === position ? [] : [[item.id, position]]));
}

type StarterLesson = { title: string; description: string };
type StarterBelt = Record<TrackCategoryKey, StarterLesson[]>;

/**
 * Trilha sugerida, pela ordem da faixa (0 = branca … 4 = preta). O professor importa como
 * rascunho, ajusta e libera; nada fica visível para o aluno sem a liberação.
 */
export const STARTER_CURRICULUM: StarterBelt[] = [
  {
    GUARD: [
      { title: 'Guarda fechada: postura e quebra', description: 'Pernas cruzadas nas costas, puxe a cabeça e quebre a postura do oponente antes de atacar.' },
      { title: 'Fuga de quadril (fuga de camarão)', description: 'Base de toda defesa: crie espaço com o quadril para repor a guarda.' },
      { title: 'Raspagem de tesoura', description: 'Da guarda fechada, pegada na gola e manga, joelho no peito e tesoura para montar.' },
    ],
    PASS: [
      { title: 'Postura dentro da guarda fechada', description: 'Coluna reta, mãos no quadril e cotovelos fechados para não ser finalizado.' },
      { title: 'Abertura da guarda em pé', description: 'Levante com base firme e use o joelho para abrir as pernas do oponente.' },
      { title: 'Passagem por baixo das pernas', description: 'Abrace uma perna, empilhe o quadril e caminhe até os 100 kg.' },
    ],
    CONTROL: [
      { title: '100 kg (controle lateral)', description: 'Peito no peito, cotovelos fechados e quadril baixo para estabilizar.' },
      { title: 'Montada', description: 'Joelhos colados, pés por baixo das pernas e equilíbrio com as mãos quando preciso.' },
      { title: 'Saída da montada (upa)', description: 'Prenda braço e perna do mesmo lado e role por cima do ombro.' },
    ],
    SUBMISSION: [
      { title: 'Armlock da guarda fechada', description: 'Controle o braço, gire o quadril e passe a perna pela cabeça.' },
      { title: 'Mata-leão', description: 'Das costas, braço no pescoço, mão no bíceps e a outra mão atrás da cabeça.' },
      { title: 'Estrangulamento cruzado', description: 'Pegadas profundas na gola e cotovelos para fora, da guarda ou da montada.' },
    ],
  },
  {
    GUARD: [
      { title: 'Guarda aberta com pegadas', description: 'Controle de manga e gola, pés no quadril e nos bíceps para manter distância.' },
      { title: 'Meia-guarda: underhook e raspagem', description: 'Ganhe o braço por baixo, fique de lado e saia para as costas ou raspe.' },
      { title: 'Guarda De La Riva', description: 'Gancho por fora da perna, pegada no tornozelo e manga para desequilibrar.' },
    ],
    PASS: [
      { title: 'Passagem toreando', description: 'Controle as calças, empurre as pernas para o lado e chegue nos 100 kg.' },
      { title: 'Passagem de joelho (knee slice)', description: 'Joelho atravessa a coxa do oponente com underhook e cabeça baixa.' },
      { title: 'Passagem da meia-guarda', description: 'Esmague o quadril, controle a cabeça e libere o joelho preso.' },
    ],
    CONTROL: [
      { title: 'Joelho na barriga', description: 'Transição dos 100 kg com pressão no abdômen e base aberta.' },
      { title: 'Pegada das costas (ganchos e cinto de segurança)', description: 'Ganchos dentro das pernas e braço por cima e por baixo do ombro.' },
      { title: 'Transições entre posições', description: '100 kg → montada → costas sem perder o contato.' },
    ],
    SUBMISSION: [
      { title: 'Triângulo', description: 'Um braço dentro e outro fora, ajuste o ângulo e feche as pernas.' },
      { title: 'Kimura', description: 'Pegada de pulso, figura-quatro e gire o braço para trás.' },
      { title: 'Omoplata', description: 'Use as pernas para prender o ombro e controle o quadril antes de finalizar.' },
    ],
  },
  {
    GUARD: [
      { title: 'Guarda X e X simples', description: 'Desequilibre de baixo com ganchos sob a perna de base.' },
      { title: 'Guarda-aranha e laço', description: 'Pés nos bíceps e pegadas na manga para controlar a distância.' },
      { title: 'Berimbolo (introdução)', description: 'Da De La Riva, inverta para chegar às costas.' },
    ],
    PASS: [
      { title: 'Passagem emborcando (over-under)', description: 'Um braço por cima e outro por baixo das pernas, pressão com o ombro.' },
      { title: 'Leg drag', description: 'Puxe a perna do oponente para o outro lado e cole o quadril.' },
      { title: 'Combinações de passagem', description: 'Encadeie toreando, knee slice e leg drag conforme a reação.' },
    ],
    CONTROL: [
      { title: 'Norte-sul', description: 'Controle invertido com peito sobre o peito e quadril baixo.' },
      { title: 'Montada técnica', description: 'Uma perna em S para manter a montada quando o oponente vira.' },
      { title: 'Retenção das costas', description: 'Ajuste o cinto de segurança e acompanhe as fugas.' },
    ],
    SUBMISSION: [
      { title: 'Chave de pé reta', description: 'Controle o tornozelo com a axila e arqueie o quadril (respeite as regras da faixa).' },
      { title: 'Ezequiel', description: 'Estrangulamento com a manga, da montada ou de dentro da guarda.' },
      { title: 'Finalizações em sequência', description: 'Triângulo → armlock → omoplata como uma única cadeia.' },
    ],
  },
  {
    GUARD: [
      { title: 'Construindo seu jogo de guarda', description: 'Escolha duas guardas principais e as raspagens que conectam entre elas.' },
      { title: 'Guarda contra pressão', description: 'Enquadramentos e recuperação quando o passador esmaga o quadril.' },
      { title: 'Ataques de perna a partir da guarda', description: 'Entradas em 50/50 e ashi garami de acordo com o regulamento.' },
    ],
    PASS: [
      { title: 'Passagem de pressão', description: 'Peso no lugar certo, sem dar espaço para reposição.' },
      { title: 'Passagem de velocidade', description: 'Mude de lado rapidamente e use fintas.' },
      { title: 'Passando contra guardas modernas', description: 'Respostas para De La Riva, berimbolo e guarda-aranha.' },
    ],
    CONTROL: [
      { title: 'Controle e desgaste', description: 'Mantenha a posição gastando pouca energia e fazendo o oponente cansar.' },
      { title: 'Armadilhas de transição', description: 'Ofereça uma saída para chegar à posição seguinte.' },
      { title: 'Pontuação e estratégia de luta', description: 'Como administrar vantagem e tempo em competição.' },
    ],
    SUBMISSION: [
      { title: 'Ataques às costas', description: 'Arco e flecha, mata-leão e armlock das costas.' },
      { title: 'Finalizações de perna', description: 'Mecânica e segurança nas chaves de calcanhar e joelho (onde permitido).' },
      { title: 'Defesas de finalização', description: 'Reconhecer cedo e sair antes do ajuste final.' },
    ],
  },
  {
    GUARD: [
      { title: 'Ensinar guarda', description: 'Como explicar os fundamentos da guarda para iniciantes.' },
      { title: 'Refinamento de detalhes', description: 'Pegadas, ângulos e tempo de cada raspagem do seu jogo.' },
      { title: 'Guarda adaptada', description: 'Ajuste do jogo para idade, peso e lesões.' },
    ],
    PASS: [
      { title: 'Sistema de passagem', description: 'Organize suas passagens em um sistema com respostas para cada guarda.' },
      { title: 'Ensinar passagem', description: 'Sequência didática para alunos de faixa branca e azul.' },
      { title: 'Estudo de lutas', description: 'Análise de vídeos de campeões para atualizar o repertório.' },
    ],
    CONTROL: [
      { title: 'Conduzir o treino', description: 'Rola posicional, aquecimento e progressão de aulas.' },
      { title: 'Segurança no tatame', description: 'Prevenção de lesões, regras e cuidado com os parceiros.' },
      { title: 'Filosofia e história', description: 'Origem do jiu-jitsu, linhagem da academia e valores do tatame.' },
    ],
    SUBMISSION: [
      { title: 'Finalização com o mínimo de força', description: 'Alavanca, tempo e posição antes da força.' },
      { title: 'Cadeias de ataque', description: 'Monte sequências próprias de finalizações.' },
      { title: 'Ensinar finalizações com segurança', description: 'Bater, soltar e progressão para iniciantes.' },
    ],
  },
];

/** Trilha sugerida para a faixa na posição `order` (faixas além da preta usam a última). */
export function starterFor(order: number): StarterBelt {
  return STARTER_CURRICULUM[Math.min(Math.max(order, 0), STARTER_CURRICULUM.length - 1)];
}
