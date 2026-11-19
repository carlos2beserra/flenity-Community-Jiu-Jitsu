-- Trilhas "Descomplicando a Faixa X" (só adiciona tabelas).
-- CreateEnum
CREATE TYPE "TrackCategory" AS ENUM ('GUARD', 'PASS', 'CONTROL', 'SUBMISSION');

-- CreateTable
CREATE TABLE "TrackLesson" (
    "id" TEXT NOT NULL,
    "academyId" TEXT NOT NULL,
    "beltId" TEXT NOT NULL,
    "category" "TrackCategory" NOT NULL,
    "title" VARCHAR(120) NOT NULL,
    "description" VARCHAR(4000),
    "mediaId" TEXT,
    "position" INTEGER NOT NULL DEFAULT 0,
    "published" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrackLesson_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrackProgress" (
    "studentId" TEXT NOT NULL,
    "lessonId" TEXT NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrackProgress_pkey" PRIMARY KEY ("studentId","lessonId")
);

-- CreateIndex
CREATE UNIQUE INDEX "TrackLesson_mediaId_key" ON "TrackLesson"("mediaId");

-- CreateIndex
CREATE INDEX "TrackLesson_academyId_beltId_category_position_idx" ON "TrackLesson"("academyId", "beltId", "category", "position");

-- CreateIndex
CREATE INDEX "TrackProgress_lessonId_idx" ON "TrackProgress"("lessonId");

-- AddForeignKey
ALTER TABLE "TrackLesson" ADD CONSTRAINT "TrackLesson_academyId_fkey" FOREIGN KEY ("academyId") REFERENCES "Academy"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrackLesson" ADD CONSTRAINT "TrackLesson_beltId_fkey" FOREIGN KEY ("beltId") REFERENCES "Belt"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrackLesson" ADD CONSTRAINT "TrackLesson_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "CommunityMedia"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrackProgress" ADD CONSTRAINT "TrackProgress_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrackProgress" ADD CONSTRAINT "TrackProgress_lessonId_fkey" FOREIGN KEY ("lessonId") REFERENCES "TrackLesson"("id") ON DELETE CASCADE ON UPDATE CASCADE;
