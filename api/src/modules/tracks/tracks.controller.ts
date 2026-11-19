import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, Roles, StudentOnly } from '../../common/auth';
import { StudentTracksService } from './student-tracks.service';
import {
  CreateTrackLessonDto,
  MoveTrackLessonDto,
  PublishTrackDto,
  StarterTrackDto,
  TrackBeltQuery,
  UpdateTrackLessonDto,
} from './tracks.dto';
import { TracksService } from './tracks.service';

const uuid = ParseUUIDPipe;

/** Professores e administradores montam as trilhas e decidem o que fica liberado. */
@Roles('ADMIN', 'INSTRUCTOR')
@Controller('tracks')
export class TracksController {
  constructor(private readonly tracks: TracksService) {}

  @Get()
  overview(@CurrentUser() user: AuthUser, @Query() query: TrackBeltQuery) {
    return this.tracks.overview(user.academyId, query.beltId);
  }

  @Post('lessons')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateTrackLessonDto) {
    return this.tracks.create(user, dto);
  }

  @Patch('lessons/:lessonId')
  update(@CurrentUser() user: AuthUser, @Param('lessonId', uuid) lessonId: string, @Body() dto: UpdateTrackLessonDto) {
    return this.tracks.update(user, lessonId, dto);
  }

  @Delete('lessons/:lessonId')
  remove(@CurrentUser() user: AuthUser, @Param('lessonId', uuid) lessonId: string) {
    return this.tracks.remove(user.academyId, lessonId);
  }

  @Post('lessons/:lessonId/move')
  move(@CurrentUser() user: AuthUser, @Param('lessonId', uuid) lessonId: string, @Body() dto: MoveTrackLessonDto) {
    return this.tracks.move(user.academyId, lessonId, dto);
  }

  @Post('publish')
  publish(@CurrentUser() user: AuthUser, @Body() dto: PublishTrackDto) {
    return this.tracks.publish(user.academyId, dto);
  }

  @Post('starter')
  importStarter(@CurrentUser() user: AuthUser, @Body() dto: StarterTrackDto) {
    return this.tracks.importStarter(user.academyId, dto);
  }
}

@StudentOnly()
@Controller('student/tracks')
export class StudentTracksController {
  constructor(private readonly tracks: StudentTracksService) {}

  @Get()
  overview(@CurrentUser() user: AuthUser, @Query() query: TrackBeltQuery) {
    return this.tracks.overview(user, query.beltId);
  }

  @Post('lessons/:lessonId/complete')
  complete(@CurrentUser() user: AuthUser, @Param('lessonId', uuid) lessonId: string) {
    return this.tracks.setCompleted(user, lessonId, true);
  }

  @Delete('lessons/:lessonId/complete')
  undo(@CurrentUser() user: AuthUser, @Param('lessonId', uuid) lessonId: string) {
    return this.tracks.setCompleted(user, lessonId, false);
  }
}
