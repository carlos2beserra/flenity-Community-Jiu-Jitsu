import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { validateMediaUpload } from '../../domain/media';
import { CommunityViews, Viewer } from './community-views';
import { MediaStorage } from './media-storage';

export type UploadedMediaFile = { buffer: Buffer; size: number };

@Injectable()
export class CommunityMediaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: MediaStorage,
    private readonly views: CommunityViews,
  ) {}

  async upload(viewer: Viewer, file: UploadedMediaFile | undefined) {
    if (!file?.buffer) throw new BadRequestException('Envie um arquivo no campo "file"');

    const validation = validateMediaUpload(file.buffer);
    if (!validation.ok) throw new BadRequestException(validation.reason);

    const storageKey = await this.storage.save(file.buffer, validation.media.extension);
    try {
      const media = await this.prisma.communityMedia.create({
        data: {
          academyId: viewer.academyId,
          ownerId: viewer.memberId,
          kind: validation.media.kind,
          mimeType: validation.media.mimeType,
          sizeBytes: file.buffer.length,
          storageKey,
        },
        select: { id: true, kind: true },
      });
      return this.views.media(media);
    } catch (error) {
      await this.storage.remove([storageKey]);
      throw error;
    }
  }

  /** Usado pela rota pública: a assinatura já foi validada pelo controller. */
  async resolve(mediaId: string) {
    const media = await this.prisma.communityMedia.findUnique({
      where: { id: mediaId },
      select: { storageKey: true, mimeType: true },
    });
    if (!media) throw new NotFoundException('Mídia não encontrada');
    return { path: this.storage.pathFor(media.storageKey), mimeType: media.mimeType };
  }

  /**
   * Garante que as mídias pertencem ao perfil, à academia e ainda não foram usadas em outra
   * publicação, flash, foto de perfil ou trilha. Retorna na ordem recebida.
   */
  async claimable(viewer: Viewer, mediaIds: string[]) {
    if (new Set(mediaIds).size !== mediaIds.length) {
      throw new BadRequestException('Mídia repetida na publicação');
    }
    if (mediaIds.length === 0) return [];
    const rows = await this.prisma.communityMedia.findMany({
      where: {
        id: { in: mediaIds },
        ownerId: viewer.memberId,
        academyId: viewer.academyId,
        postMedia: { is: null },
        stories: { none: {} },
        avatarOf: { is: null },
        lesson: { is: null },
      },
      select: { id: true, kind: true },
    });
    if (rows.length !== mediaIds.length) {
      throw new BadRequestException('Mídia inválida ou já utilizada');
    }
    const byId = new Map(rows.map((row) => [row.id, row]));
    return mediaIds.map((id) => byId.get(id)!);
  }

  /** Apaga registros e arquivos de mídias que deixaram de ser usadas. */
  async discard(mediaIds: string[]) {
    if (mediaIds.length === 0) return;
    const rows = await this.prisma.communityMedia.findMany({
      where: { id: { in: mediaIds } },
      select: { storageKey: true },
    });
    await this.prisma.communityMedia.deleteMany({ where: { id: { in: mediaIds } } });
    await this.storage.remove(rows.map((row) => row.storageKey));
  }
}
