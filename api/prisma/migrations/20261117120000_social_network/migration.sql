-- CreateEnum
CREATE TYPE "MediaKind" AS ENUM ('IMAGE', 'VIDEO');

-- CreateEnum
CREATE TYPE "CommunityPostKind" AS ENUM ('POST', 'REEL');

-- CreateEnum
CREATE TYPE "CommunityNotificationType" AS ENUM ('LIKE', 'COMMENT', 'FOLLOW');

-- AlterTable
ALTER TABLE "CommunityPost" ADD COLUMN     "kind" "CommunityPostKind" NOT NULL DEFAULT 'POST',
ALTER COLUMN "content" SET DEFAULT '',
ALTER COLUMN "content" SET DATA TYPE VARCHAR(2200);

-- AlterTable
ALTER TABLE "Student" ADD COLUMN     "avatarMediaId" TEXT,
ADD COLUMN     "bio" VARCHAR(150);

-- CreateTable
CREATE TABLE "CommunityMedia" (
    "id" TEXT NOT NULL,
    "academyId" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "kind" "MediaKind" NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "storageKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityMedia_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityPostMedia" (
    "postId" TEXT NOT NULL,
    "mediaId" TEXT NOT NULL,
    "position" INTEGER NOT NULL,

    CONSTRAINT "CommunityPostMedia_pkey" PRIMARY KEY ("postId","position")
);

-- CreateTable
CREATE TABLE "CommunityFollow" (
    "followerId" TEXT NOT NULL,
    "followingId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityFollow_pkey" PRIMARY KEY ("followerId","followingId")
);

-- CreateTable
CREATE TABLE "CommunityPostSave" (
    "postId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityPostSave_pkey" PRIMARY KEY ("postId","studentId")
);

-- CreateTable
CREATE TABLE "CommunityStory" (
    "id" TEXT NOT NULL,
    "academyId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "mediaId" TEXT NOT NULL,
    "caption" VARCHAR(200),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CommunityStory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityStoryView" (
    "storyId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "viewedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityStoryView_pkey" PRIMARY KEY ("storyId","studentId")
);

-- CreateTable
CREATE TABLE "CommunityNotification" (
    "id" TEXT NOT NULL,
    "academyId" TEXT NOT NULL,
    "recipientId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "type" "CommunityNotificationType" NOT NULL,
    "postId" TEXT,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityNotification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CommunityMedia_storageKey_key" ON "CommunityMedia"("storageKey");

-- CreateIndex
CREATE INDEX "CommunityMedia_academyId_ownerId_idx" ON "CommunityMedia"("academyId", "ownerId");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityPostMedia_mediaId_key" ON "CommunityPostMedia"("mediaId");

-- CreateIndex
CREATE INDEX "CommunityFollow_followingId_createdAt_idx" ON "CommunityFollow"("followingId", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityPostSave_studentId_createdAt_idx" ON "CommunityPostSave"("studentId", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityStory_academyId_expiresAt_idx" ON "CommunityStory"("academyId", "expiresAt");

-- CreateIndex
CREATE INDEX "CommunityStory_studentId_expiresAt_idx" ON "CommunityStory"("studentId", "expiresAt");

-- CreateIndex
CREATE INDEX "CommunityNotification_recipientId_createdAt_idx" ON "CommunityNotification"("recipientId", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityNotification_recipientId_readAt_idx" ON "CommunityNotification"("recipientId", "readAt");

-- CreateIndex
CREATE INDEX "CommunityPost_academyId_kind_createdAt_idx" ON "CommunityPost"("academyId", "kind", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityPost_studentId_createdAt_idx" ON "CommunityPost"("studentId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Student_avatarMediaId_key" ON "Student"("avatarMediaId");

-- AddForeignKey
ALTER TABLE "Student" ADD CONSTRAINT "Student_avatarMediaId_fkey" FOREIGN KEY ("avatarMediaId") REFERENCES "CommunityMedia"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityMedia" ADD CONSTRAINT "CommunityMedia_academyId_fkey" FOREIGN KEY ("academyId") REFERENCES "Academy"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityMedia" ADD CONSTRAINT "CommunityMedia_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityPostMedia" ADD CONSTRAINT "CommunityPostMedia_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityPostMedia" ADD CONSTRAINT "CommunityPostMedia_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "CommunityMedia"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityFollow" ADD CONSTRAINT "CommunityFollow_followerId_fkey" FOREIGN KEY ("followerId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityFollow" ADD CONSTRAINT "CommunityFollow_followingId_fkey" FOREIGN KEY ("followingId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityPostSave" ADD CONSTRAINT "CommunityPostSave_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityPostSave" ADD CONSTRAINT "CommunityPostSave_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityStory" ADD CONSTRAINT "CommunityStory_academyId_fkey" FOREIGN KEY ("academyId") REFERENCES "Academy"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityStory" ADD CONSTRAINT "CommunityStory_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityStory" ADD CONSTRAINT "CommunityStory_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "CommunityMedia"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityStoryView" ADD CONSTRAINT "CommunityStoryView_storyId_fkey" FOREIGN KEY ("storyId") REFERENCES "CommunityStory"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityStoryView" ADD CONSTRAINT "CommunityStoryView_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityNotification" ADD CONSTRAINT "CommunityNotification_academyId_fkey" FOREIGN KEY ("academyId") REFERENCES "Academy"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityNotification" ADD CONSTRAINT "CommunityNotification_recipientId_fkey" FOREIGN KEY ("recipientId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityNotification" ADD CONSTRAINT "CommunityNotification_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityNotification" ADD CONSTRAINT "CommunityNotification_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

