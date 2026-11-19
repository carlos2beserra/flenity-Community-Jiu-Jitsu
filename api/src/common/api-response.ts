import {
  ArgumentsHost,
  CallHandler,
  Catch,
  ExceptionFilter,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Response } from 'express';
import { map, Observable } from 'rxjs';

export type ApiError = { code: string; message: string; details?: unknown };
export type ApiResponse<T> = { success: boolean; data: T | null; error: ApiError | null };

/** Envolve toda resposta de sucesso em { success, data, error }. */
@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, ApiResponse<T>> {
  intercept(_context: ExecutionContext, next: CallHandler<T>): Observable<ApiResponse<T>> {
    return next.handle().pipe(map((data) => ({ success: true, data: data ?? null, error: null })));
  }
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<{ method: string; url: string }>();
    const { status, error } = this.toApiError(exception);

    if (status >= 500) {
      this.logger.error(`${request.method} ${request.url} falhou`, exception instanceof Error ? exception.stack : String(exception));
    }
    response.status(status).json({ success: false, data: null, error } satisfies ApiResponse<null>);
  }

  private toApiError(exception: unknown): { status: number; error: ApiError } {
    if (exception instanceof HttpException) {
      const body = exception.getResponse();
      const message = typeof body === 'string' ? body : (body as { message?: unknown }).message;
      return {
        status: exception.getStatus(),
        error: {
          code: HttpStatus[exception.getStatus()] ?? 'ERROR',
          message: Array.isArray(message) ? 'Dados inválidos' : String(message ?? exception.message),
          details: Array.isArray(message) ? message : undefined,
        },
      };
    }
    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        return { status: 409, error: { code: 'CONFLICT', message: 'Registro duplicado' } };
      }
      if (exception.code === 'P2025') {
        return { status: 404, error: { code: 'NOT_FOUND', message: 'Registro não encontrado' } };
      }
      if (exception.code === 'P2003') {
        return { status: 409, error: { code: 'CONFLICT', message: 'Registro em uso por outros dados' } };
      }
    }
    return { status: 500, error: { code: 'INTERNAL_SERVER_ERROR', message: 'Erro interno' } };
  }
}
