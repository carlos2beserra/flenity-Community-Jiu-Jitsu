import { Module } from '@nestjs/common';
import { CheckInsModule } from '../checkins/checkins.module';
import { GraduationsModule } from '../graduations/graduations.module';
import { StudentAppController } from './student-app.controller';
import {
  CommunityPostsController,
  CommunitySocialController,
  StudentCommunitiesController,
} from './community.controller';
import { CommunityService } from './community.service';
import { CommunityMediaService } from './community-media.service';
import { CommunityMembersService } from './community-members.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { CommunityPostsService } from './community-posts.service';
import { CommunityProfilesService } from './community-profiles.service';
import { CommunityStoriesService } from './community-stories.service';
import { CommunityViews } from './community-views';
import { MediaController } from './media.controller';
import { MediaStorage } from './media-storage';
import { MediaUrlSigner } from './media-url.signer';
import { StudentAppService } from './student-app.service';

@Module({
  imports: [CheckInsModule, GraduationsModule],
  controllers: [
    StudentAppController,
    StudentCommunitiesController,
    CommunityPostsController,
    CommunitySocialController,
    MediaController,
  ],
  providers: [
    StudentAppService,
    CommunityService,
    CommunityPostsService,
    CommunityProfilesService,
    CommunityStoriesService,
    CommunityNotificationsService,
    CommunityMediaService,
    CommunityMembersService,
    CommunityViews,
    MediaStorage,
    MediaUrlSigner,
  ],
  exports: [CommunityMembersService, CommunityMediaService, CommunityViews],
})
export class StudentAppModule {}
