import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { mkdir, unlink, writeFile } from 'fs/promises';
import { join, resolve } from 'path';

/** Somente nomes gerados pelo servidor: impede path traversal ao ler ou apagar arquivos. */
const STORAGE_KEY = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp|mp4|mov)$/;

@Injectable()
export class MediaStorage {
  private readonly logger = new Logger(MediaStorage.name);
  private readonly root: string;

  constructor(config: ConfigService) {
    this.root = resolve(config.get<string>('MEDIA_DIR') ?? 'storage/media');
  }

  async save(buffer: Buffer, extension: string): Promise<string> {
    const key = `${randomUUID()}.${extension}`;
    await mkdir(this.root, { recursive: true });
    await writeFile(this.pathFor(key), buffer, { flag: 'wx' });
    return key;
  }

  pathFor(key: string): string {
    if (!STORAGE_KEY.test(key)) throw new Error('Chave de mídia inválida');
    return join(this.root, key);
  }

  /** Remoção best-effort: o registro já saiu do banco; um arquivo órfão não deve derrubar a requisição. */
  async remove(keys: string[]): Promise<void> {
    await Promise.all(
      keys.map(async (key) => {
        try {
          await unlink(this.pathFor(key));
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
            this.logger.warn(`Falha ao remover mídia ${key}: ${(error as Error).message}`);
          }
        }
      }),
    );
  }
}
