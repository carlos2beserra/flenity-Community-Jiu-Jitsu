import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class PaginationQuery {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page: number = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  pageSize: number = 20;

  @IsOptional() @IsString()
  search?: string;
}

export type Paginated<T> = { items: T[]; total: number; page: number; pageSize: number };

export function paginationArgs(query: PaginationQuery) {
  return { skip: (query.page - 1) * query.pageSize, take: query.pageSize };
}

export function toPaginated<T>(items: T[], total: number, query: PaginationQuery): Paginated<T> {
  return { items, total, page: query.page, pageSize: query.pageSize };
}
