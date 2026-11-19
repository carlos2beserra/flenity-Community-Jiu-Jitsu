import { Controller, ForbiddenException, Get, Param, ParseUUIDPipe, Query, Res } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Response } from 'express';
import { Public } from '../../common/auth';
import { CommunityMediaService } from './community-media.service';
import { MediaUrlSigner } from './media-url.signer';

/**
 * Entrega fotos e vídeos da comunidade. Não usa JWT: a URL é assinada e expira, o que permite carregar
 * mídia em <img>, Image.network e players de vídeo (com suporte a Range).
 */
@Public()
@SkipThrottle()
@Controller('media')
export class MediaController {
  constructor(
    private readonly signer: MediaUrlSigner,
    private readonly media: CommunityMediaService,
  ) {}

  @Get(':mediaId')
  async serve(
    @Param('mediaId', ParseUUIDPipe) mediaId: string,
    @Query('exp') exp: string | undefined,
    @Query('sig') sig: string | undefined,
    @Res() res: Response,
  ) {
    if (!exp || !sig || !/^\d{1,12}$/.test(exp) || !this.signer.verify(mediaId, Number(exp), sig)) {
      throw new ForbiddenException('Link de mídia inválido ou expirado');
    }
    const file = await this.media.resolve(mediaId);
    res.sendFile(file.path, {
      headers: {
        'Content-Type': file.mimeType,
        'Cache-Control': 'private, max-age=43200, immutable',
        'X-Content-Type-Options': 'nosniff',
        'Content-Disposition': 'inline',
      },
    });
  }
}
