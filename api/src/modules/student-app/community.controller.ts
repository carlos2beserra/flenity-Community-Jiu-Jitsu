import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { AllAuthenticated, AuthUser, CurrentUser, StudentOnly } from '../../common/auth';
import { PaginationQuery } from '../../common/pagination';
import { MAX_VIDEO_BYTES } from '../../domain/media';
import {
  CommunityCommentDto,
  CommunityFeedQuery,
  CommunityInviteDto,
  CommunityPostDto,
  CommunityProfileDto,
  CommunityStoryDto,
} from './community.dto';
import { CommunityService } from './community.service';
import { CommunityMediaService, UploadedMediaFile } from './community-media.service';
import { CommunityMembersService } from './community-members.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { CommunityPostsService } from './community-posts.service';
import { CommunityProfilesService } from './community-profiles.service';
import { CommunityStoriesService } from './community-stories.service';

const uuid = ParseUUIDPipe;

@StudentOnly()
@Controller('student/communities')
export class StudentCommunitiesController {
  constructor(private readonly community: CommunityService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.community.communities(user.userId, user.academyId);
  }

  @Post('invitations/accept')
  accept(@CurrentUser() user: AuthUser, @Body() dto: CommunityInviteDto) {
    return this.community.acceptInvite(user.userId, user.academyId, dto);
  }

  @Post(':studentId/switch')
  switch(@CurrentUser() user: AuthUser, @Param('studentId', uuid) studentId: string) {
    return this.community.switchCommunity(user.userId, user.academyId, studentId);
  }
}

/** Rotas sociais: alunos e equipe da academia participam com o mesmo tipo de perfil. */
@AllAuthenticated()
@Controller('student/community/posts')
export class CommunityPostsController {
  constructor(
    private readonly posts: CommunityPostsService,
    private readonly members: CommunityMembersService,
  ) {}

  @Get()
  async list(@CurrentUser() user: AuthUser, @Query() query: CommunityFeedQuery) {
    return this.posts.feed(await this.members.resolve(user), query);
  }

  @Post()
  async create(@CurrentUser() user: AuthUser, @Body() dto: CommunityPostDto) {
    return this.posts.createPost(await this.members.resolve(user), dto);
  }

  @Get(':postId')
  async findOne(@CurrentUser() user: AuthUser, @Param('postId', uuid) postId: string) {
    return this.posts.findOne(await this.members.resolve(user), postId);
  }

  @Delete(':postId')
  async remove(@CurrentUser() user: AuthUser, @Param('postId', uuid) postId: string) {
    return this.posts.deletePost(await this.members.resolve(user), postId);
  }

  @Post(':postId/like')
  async toggleLike(@CurrentUser() user: AuthUser, @Param('postId', uuid) postId: string) {
    return this.posts.toggleLike(await this.members.resolve(user), postId);
  }

  @Post(':postId/save')
  async toggleSave(@CurrentUser() user: AuthUser, @Param('postId', uuid) postId: string) {
    return this.posts.toggleSave(await this.members.resolve(user), postId);
  }

  @Get(':postId/comments')
  async comments(
    @CurrentUser() user: AuthUser,
    @Param('postId', uuid) postId: string,
    @Query() query: PaginationQuery,
  ) {
    return this.posts.comments(await this.members.resolve(user), postId, query);
  }

  @Post(':postId/comments')
  async addComment(
    @CurrentUser() user: AuthUser,
    @Param('postId', uuid) postId: string,
    @Body() dto: CommunityCommentDto,
  ) {
    return this.posts.addComment(await this.members.resolve(user), postId, dto);
  }

  @Delete(':postId/comments/:commentId')
  async deleteComment(
    @CurrentUser() user: AuthUser,
    @Param('postId', uuid) postId: string,
    @Param('commentId', uuid) commentId: string,
  ) {
    return this.posts.deleteComment(await this.members.resolve(user), postId, commentId);
  }
}

@AllAuthenticated()
@Controller('student/community')
export class CommunitySocialController {
  constructor(
    private readonly members: CommunityMembersService,
    private readonly posts: CommunityPostsService,
    private readonly profiles: CommunityProfilesService,
    private readonly stories: CommunityStoriesService,
    private readonly notifications: CommunityNotificationsService,
    private readonly media: CommunityMediaService,
  ) {}

  @Post('media')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_VIDEO_BYTES, files: 1 } }))
  async upload(@CurrentUser() user: AuthUser, @UploadedFile() file: UploadedMediaFile | undefined) {
    return this.media.upload(await this.members.resolve(user), file);
  }

  @Get('explore')
  async explore(@CurrentUser() user: AuthUser, @Query() query: PaginationQuery) {
    return this.posts.explore(await this.members.resolve(user), query);
  }

  @Get('saved')
  async saved(@CurrentUser() user: AuthUser, @Query() query: PaginationQuery) {
    return this.posts.saved(await this.members.resolve(user), query);
  }

  @Get('people')
  async people(@CurrentUser() user: AuthUser, @Query() query: PaginationQuery) {
    return this.profiles.search(await this.members.resolve(user), query);
  }

  @Get('people/me')
  async me(@CurrentUser() user: AuthUser) {
    const viewer = await this.members.resolve(user);
    return this.profiles.profile(viewer, viewer.memberId);
  }

  @Get('people/:memberId')
  async profile(@CurrentUser() user: AuthUser, @Param('memberId', uuid) memberId: string) {
    return this.profiles.profile(await this.members.resolve(user), memberId);
  }

  @Get('people/:memberId/followers')
  async followers(
    @CurrentUser() user: AuthUser,
    @Param('memberId', uuid) memberId: string,
    @Query() query: PaginationQuery,
  ) {
    return this.profiles.followers(await this.members.resolve(user), memberId, query);
  }

  @Get('people/:memberId/following')
  async following(
    @CurrentUser() user: AuthUser,
    @Param('memberId', uuid) memberId: string,
    @Query() query: PaginationQuery,
  ) {
    return this.profiles.following(await this.members.resolve(user), memberId, query);
  }

  @Post('people/:memberId/follow')
  async toggleFollow(@CurrentUser() user: AuthUser, @Param('memberId', uuid) memberId: string) {
    return this.profiles.toggleFollow(await this.members.resolve(user), memberId);
  }

  @Patch('profile')
  async updateProfile(@CurrentUser() user: AuthUser, @Body() dto: CommunityProfileDto) {
    return this.profiles.updateProfile(await this.members.resolve(user), dto);
  }

  @Get('stories')
  async storyTray(@CurrentUser() user: AuthUser) {
    return this.stories.tray(await this.members.resolve(user));
  }

  @Post('stories')
  async createStory(@CurrentUser() user: AuthUser, @Body() dto: CommunityStoryDto) {
    return this.stories.create(await this.members.resolve(user), dto);
  }

  @Post('stories/:storyId/view')
  async viewStory(@CurrentUser() user: AuthUser, @Param('storyId', uuid) storyId: string) {
    return this.stories.markViewed(await this.members.resolve(user), storyId);
  }

  @Get('stories/:storyId/viewers')
  async storyViewers(@CurrentUser() user: AuthUser, @Param('storyId', uuid) storyId: string) {
    return this.stories.viewers(await this.members.resolve(user), storyId);
  }

  @Delete('stories/:storyId')
  async deleteStory(@CurrentUser() user: AuthUser, @Param('storyId', uuid) storyId: string) {
    return this.stories.remove(await this.members.resolve(user), storyId);
  }

  @Get('notifications')
  async notificationList(@CurrentUser() user: AuthUser, @Query() query: PaginationQuery) {
    return this.notifications.list(await this.members.resolve(user), query);
  }

  @Get('notifications/unread-count')
  async unreadCount(@CurrentUser() user: AuthUser) {
    return this.notifications.unreadCount(await this.members.resolve(user));
  }

  @Post('notifications/read')
  async markRead(@CurrentUser() user: AuthUser) {
    return this.notifications.markAllRead(await this.members.resolve(user));
  }
}
