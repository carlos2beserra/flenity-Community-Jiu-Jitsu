import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { mediaUrlExpiry, signMediaId, verifyMediaSignature } from '../../domain/media';

/** Gera e confere URLs assinadas de mídia (`/media/:id?exp=&sig=`), relativas à base da API. */
@Injectable()
export class MediaUrlSigner {
  private readonly secret: string;

  constructor(config: ConfigService) {
    const base = config.get<string>('MEDIA_URL_SECRET') ?? config.getOrThrow<string>('JWT_SECRET');
    // Chave derivada: uma assinatura de mídia nunca serve como assinatura de JWT, e vice-versa.
    this.secret = createHash('sha256').update(`flenity-media:${base}`).digest('hex');
  }

  url(mediaId: string, nowSeconds = Math.floor(Date.now() / 1000)): string {
    const exp = mediaUrlExpiry(nowSeconds);
    return `/media/${mediaId}?exp=${exp}&sig=${signMediaId(this.secret, mediaId, exp)}`;
  }

  verify(mediaId: string, exp: number, sig: string, nowSeconds = Math.floor(Date.now() / 1000)): boolean {
    return verifyMediaSignature(this.secret, mediaId, exp, sig, nowSeconds);
  }
}
