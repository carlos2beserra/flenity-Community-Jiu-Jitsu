import {
  detectMedia,
  MAX_IMAGE_BYTES,
  mediaUrlExpiry,
  signMediaId,
  validateMediaUpload,
  verifyMediaSignature,
} from './media';

const withHeader = (header: number[] | string, size = 64) => {
  const bytes = typeof header === 'string' ? Buffer.from(header, 'latin1') : Buffer.from(header);
  return Buffer.concat([bytes, Buffer.alloc(Math.max(0, size - bytes.length))]);
};

describe('detectMedia', () => {
  it('reconhece JPEG, PNG e WEBP pelos bytes iniciais', () => {
    expect(detectMedia(withHeader([0xff, 0xd8, 0xff, 0xe0]))?.mimeType).toBe('image/jpeg');
    expect(detectMedia(withHeader([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))?.mimeType).toBe('image/png');
    expect(detectMedia(withHeader('RIFF\0\0\0\0WEBPVP8 '))?.mimeType).toBe('image/webp');
  });

  it('reconhece vídeos MP4 e MOV', () => {
    expect(detectMedia(withHeader('\0\0\0\x18ftypisom'))).toEqual({
      kind: 'VIDEO',
      mimeType: 'video/mp4',
      extension: 'mp4',
    });
    expect(detectMedia(withHeader('\0\0\0\x14ftypqt  '))?.mimeType).toBe('video/quicktime');
  });

  it('recusa HEIC, executáveis e texto disfarçados', () => {
    expect(detectMedia(withHeader('\0\0\0\x18ftypheic'))).toBeNull();
    expect(detectMedia(withHeader('MZ\x90\0'))).toBeNull();
    expect(detectMedia(withHeader('<svg xmlns="http://www.w3.org/2000/svg">'))).toBeNull();
  });
});

describe('validateMediaUpload', () => {
  it('recusa arquivo vazio e imagem acima do limite', () => {
    expect(validateMediaUpload(Buffer.alloc(0))).toEqual({ ok: false, reason: 'Arquivo vazio' });
    const huge = withHeader([0xff, 0xd8, 0xff], MAX_IMAGE_BYTES + 1);
    expect(validateMediaUpload(huge)).toEqual({ ok: false, reason: 'Arquivo muito grande (máximo 10 MB)' });
  });

  it('aceita uma imagem válida', () => {
    expect(validateMediaUpload(withHeader([0xff, 0xd8, 0xff]))).toMatchObject({ ok: true });
  });
});

describe('URLs assinadas de mídia', () => {
  const secret = 'segredo-de-teste';
  const now = 1_800_000_100;

  it('aceita a assinatura correta antes de expirar', () => {
    const exp = now + 60;
    const sig = signMediaId(secret, 'media-1', exp);
    expect(verifyMediaSignature(secret, 'media-1', exp, sig, now)).toBe(true);
  });

  it('recusa assinatura expirada, de outra mídia ou malformada', () => {
    const exp = now + 60;
    const sig = signMediaId(secret, 'media-1', exp);
    expect(verifyMediaSignature(secret, 'media-1', exp, sig, exp + 1)).toBe(false);
    expect(verifyMediaSignature(secret, 'media-2', exp, sig, now)).toBe(false);
    expect(verifyMediaSignature(secret, 'media-1', exp + 1, sig, now)).toBe(false);
    expect(verifyMediaSignature(secret, 'media-1', exp, 'abc', now)).toBe(false);
  });

  it('arredonda a expiração para a próxima hora cheia', () => {
    const exp = mediaUrlExpiry(now);
    expect(exp % 3600).toBe(0);
    expect(exp).toBeGreaterThanOrEqual(now + 12 * 3600);
    expect(mediaUrlExpiry(now + 10)).toBe(exp);
  });
});
