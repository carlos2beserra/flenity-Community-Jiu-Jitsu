-- Multi-academy student accounts and community features.
CREATE TABLE "StudentAccount" (
    "id" TEXT NOT NULL,
    "email" TEXT,
    "passwordHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "StudentAccount_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "Student" ADD COLUMN "accountId" TEXT;

INSERT INTO "StudentAccount" ("id", "email", "passwordHash", "createdAt")
SELECT "id", "email", "passwordHash", "createdAt" FROM "Student";

UPDATE "Student" SET "accountId" = "id";

CREATE INDEX "StudentAccount_email_idx" ON "StudentAccount"("email");
CREATE UNIQUE INDEX "Student_accountId_academyId_key" ON "Student"("accountId", "academyId");
ALTER TABLE "Student" ADD CONSTRAINT "Student_accountId_fkey"
  FOREIGN KEY ("accountId") REFERENCES "StudentAccount"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "CommunityInvite" (
    "id" TEXT NOT NULL,
    "academyId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "acceptedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CommunityInvite_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "CommunityPost" (
    "id" TEXT NOT NULL,
    "academyId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "content" VARCHAR(2000) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CommunityPost_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "CommunityPostLike" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CommunityPostLike_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "CommunityPostComment" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "content" VARCHAR(1000) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CommunityPostComment_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "CommunityInvite_tokenHash_key" ON "CommunityInvite"("tokenHash");
CREATE INDEX "CommunityInvite_academyId_studentId_acceptedAt_idx"
  ON "CommunityInvite"("academyId", "studentId", "acceptedAt");
CREATE INDEX "CommunityPost_academyId_createdAt_idx" ON "CommunityPost"("academyId", "createdAt");
CREATE UNIQUE INDEX "CommunityPostLike_postId_studentId_key" ON "CommunityPostLike"("postId", "studentId");
CREATE INDEX "CommunityPostComment_postId_createdAt_idx" ON "CommunityPostComment"("postId", "createdAt");

ALTER TABLE "CommunityInvite" ADD CONSTRAINT "CommunityInvite_academyId_fkey"
  FOREIGN KEY ("academyId") REFERENCES "Academy"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityInvite" ADD CONSTRAINT "CommunityInvite_studentId_fkey"
  FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPost" ADD CONSTRAINT "CommunityPost_academyId_fkey"
  FOREIGN KEY ("academyId") REFERENCES "Academy"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPost" ADD CONSTRAINT "CommunityPost_studentId_fkey"
  FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPostLike" ADD CONSTRAINT "CommunityPostLike_postId_fkey"
  FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPostLike" ADD CONSTRAINT "CommunityPostLike_studentId_fkey"
  FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPostComment" ADD CONSTRAINT "CommunityPostComment_postId_fkey"
  FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPostComment" ADD CONSTRAINT "CommunityPostComment_studentId_fkey"
  FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;
