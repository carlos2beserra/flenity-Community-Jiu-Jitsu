import { createHmac, timingSafeEqual } from 'crypto';

export type MediaKindName = 'IMAGE' | 'VIDEO';
export type DetectedMedia = { kind: MediaKindName; mimeType: string; extension: string };

export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
export const MAX_VIDEO_BYTES = 60 * 1024 * 1024;
/** Validade das URLs assinadas de mídia. */
export const MEDIA_URL_TTL_SECONDS = 12 * 60 * 60;

const startsWith = (buffer: Buffer, bytes: number[], offset = 0) =>
  buffer.length >= offset + bytes.length && bytes.every((byte, i) => buffer[offset + i] === byte);

const ascii = (buffer: Buffer, start: number, end: number) =>
  buffer.length >= end ? buffer.subarray(start, end).toString('latin1') : '';

/**
 * Identifica o formato pelos bytes iniciais (magic numbers), nunca pelo nome ou Content-Type enviados
 * pelo cliente. Só aceita formatos que o app sabe exibir.
 */
export function detectMedia(buffer: Buffer): DetectedMedia | null {
  if (startsWith(buffer, [0xff, 0xd8, 0xff])) {
    return { kind: 'IMAGE', mimeType: 'image/jpeg', extension: 'jpg' };
  }
  if (startsWith(buffer, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return { kind: 'IMAGE', mimeType: 'image/png', extension: 'png' };
  }
  if (ascii(buffer, 0, 4) === 'RIFF' && ascii(buffer, 8, 12) === 'WEBP') {
    return { kind: 'IMAGE', mimeType: 'image/webp', extension: 'webp' };
  }
  if (ascii(buffer, 4, 8) === 'ftyp') {
    const brand = ascii(buffer, 8, 12);
    if (brand === 'qt  ') return { kind: 'VIDEO', mimeType: 'video/quicktime', extension: 'mov' };
    if (['heic', 'heix', 'mif1', 'msf1', 'avif'].includes(brand)) return null;
    return { kind: 'VIDEO', mimeType: 'video/mp4', extension: 'mp4' };
  }
  return null;
}

export type MediaValidation =
  | { ok: true; media: DetectedMedia }
  | { ok: false; reason: string };

export function validateMediaUpload(buffer: Buffer): MediaValidation {
  if (buffer.length === 0) return { ok: false, reason: 'Arquivo vazio' };
  const media = detectMedia(buffer);
  if (!media) return { ok: false, reason: 'Formato não suportado. Envie JPG, PNG, WEBP, MP4 ou MOV' };
  const limit = media.kind === 'IMAGE' ? MAX_IMAGE_BYTES : MAX_VIDEO_BYTES;
  if (buffer.length > limit) {
    const mb = Math.round(limit / (1024 * 1024));
    return { ok: false, reason: `Arquivo muito grande (máximo ${mb} MB)` };
  }
  return { ok: true, media };
}

const signaturePayload = (mediaId: string, expiresAt: number) => `${mediaId}.${expiresAt}`;

export function signMediaId(secret: string, mediaId: string, expiresAt: number): string {
  return createHmac('sha256', secret).update(signaturePayload(mediaId, expiresAt)).digest('hex');
}

/**
 * URLs de mídia são assinadas (HMAC) e expiram, para que imagens e vídeos carreguem em players e
 * no Image.network sem expor o JWT na URL.
 */
export function verifyMediaSignature(
  secret: string,
  mediaId: string,
  expiresAt: number,
  signature: string,
  nowSeconds: number,
): boolean {
  if (!Number.isSafeInteger(expiresAt) || expiresAt < nowSeconds) return false;
  if (!/^[a-f0-9]{64}$/.test(signature)) return false;
  const expected = Buffer.from(signMediaId(secret, mediaId, expiresAt), 'hex');
  return timingSafeEqual(expected, Buffer.from(signature, 'hex'));
}

/** Expiração arredondada à hora: a URL fica estável por um tempo e o app reaproveita o cache de imagem. */
export function mediaUrlExpiry(nowSeconds: number): number {
  const hour = 60 * 60;
  return Math.ceil((nowSeconds + MEDIA_URL_TTL_SECONDS) / hour) * hour;
}
