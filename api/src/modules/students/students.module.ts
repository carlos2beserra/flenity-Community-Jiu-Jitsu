import { Module } from '@nestjs/common';
import { StudentsController } from './students.controller';
import { StudentsService } from './students.service';
import { CommunityService } from '../student-app/community.service';

@Module({ controllers: [StudentsController], providers: [StudentsService, CommunityService] })
export class StudentsModule {}
