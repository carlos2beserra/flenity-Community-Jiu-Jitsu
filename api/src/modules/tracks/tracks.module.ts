import { Module } from '@nestjs/common';
import { StudentAppModule } from '../student-app/student-app.module';
import { StudentTracksService } from './student-tracks.service';
import { TrackViews } from './track-views';
import { StudentTracksController, TracksController } from './tracks.controller';
import { TracksService } from './tracks.service';

@Module({
  imports: [StudentAppModule],
  controllers: [TracksController, StudentTracksController],
  providers: [TracksService, StudentTracksService, TrackViews],
})
export class TracksModule {}
