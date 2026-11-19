export const STORY_TTL_HOURS = 24;
export const MAX_POST_MEDIA = 10;

export function storyExpiresAt(createdAt: Date): Date {
  return new Date(createdAt.getTime() + STORY_TTL_HOURS * 60 * 60 * 1000);
}

/** Ninguém recebe notificação de uma ação feita por si mesmo. */
export function shouldNotify(actorId: string, recipientId: string): boolean {
  return actorId !== recipientId;
}

export type ExploreCandidate = { id: string; likes: number; comments: number; createdAt: Date };

/**
 * Pontuação do Explorar: engajamento (comentário vale mais que curtida) com decaimento por idade,
 * para que publicações recentes e populares apareçam primeiro.
 */
export function exploreScore(candidate: ExploreCandidate, now: Date): number {
  const ageHours = Math.max(0, (now.getTime() - candidate.createdAt.getTime()) / 3_600_000);
  const engagement = candidate.likes + candidate.comments * 2 + 1;
  return engagement / Math.pow(ageHours + 2, 1.5);
}

export function rankForExplore(candidates: ExploreCandidate[], now: Date): string[] {
  return [...candidates]
    .sort((a, b) => exploreScore(b, now) - exploreScore(a, now) || b.createdAt.getTime() - a.createdAt.getTime())
    .map((candidate) => candidate.id);
}

export type PostMediaRule = { kind: 'POST' | 'REEL'; content: string; mediaKinds: Array<'IMAGE' | 'VIDEO'> };

/** Regras de publicação: publicação precisa de texto ou mídia (até 10); rola é exatamente um vídeo. */
export function validatePostShape(rule: PostMediaRule): string | null {
  if (rule.mediaKinds.length > MAX_POST_MEDIA) return `Use no máximo ${MAX_POST_MEDIA} fotos ou vídeos`;
  if (rule.kind === 'REEL') {
    if (rule.mediaKinds.length !== 1 || rule.mediaKinds[0] !== 'VIDEO') {
      return 'Um rola precisa de exatamente um vídeo';
    }
    return null;
  }
  if (!rule.content && rule.mediaKinds.length === 0) return 'Escreva algo ou adicione uma foto';
  return null;
}

/** @usuario derivado do nome, igual ao exibido no app (ex.: "Ana Silva" → "ana.silva"). */
export function handleFromName(name: string): string {
  const handle = name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/^\.+|\.+$/g, '');
  return handle || 'aluno';
}
