-- Perfil social único (CommunityMember) para alunos e equipe.
-- Todo o conteúdo social existente é preservado: cada aluno ganha um perfil e as
-- referências passam de Student.id para CommunityMember.id antes de as colunas antigas saírem.

-- 1. Tabela de perfis
CREATE TABLE "CommunityMember" (
    "id" TEXT NOT NULL,
    "academyId" TEXT NOT NULL,
    "studentId" TEXT,
    "userId" TEXT,
    "bio" VARCHAR(150),
    "avatarMediaId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityMember_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "CommunityMember_owner_check" CHECK (("studentId" IS NULL) <> ("userId" IS NULL))
);

CREATE UNIQUE INDEX "CommunityMember_studentId_key" ON "CommunityMember"("studentId");
CREATE UNIQUE INDEX "CommunityMember_userId_key" ON "CommunityMember"("userId");
CREATE UNIQUE INDEX "CommunityMember_avatarMediaId_key" ON "CommunityMember"("avatarMediaId");
CREATE INDEX "CommunityMember_academyId_idx" ON "CommunityMember"("academyId");

-- 2. Um perfil por aluno, levando bio e foto que estavam no cadastro do aluno
INSERT INTO "CommunityMember" ("id", "academyId", "studentId", "bio", "avatarMediaId", "createdAt")
SELECT gen_random_uuid()::text, s."academyId", s."id", s."bio", s."avatarMediaId", s."createdAt"
FROM "Student" s;

-- 3. Solta as chaves estrangeiras antigas (apontavam para Student)
ALTER TABLE "Student" DROP CONSTRAINT "Student_avatarMediaId_fkey";
ALTER TABLE "CommunityPost" DROP CONSTRAINT "CommunityPost_studentId_fkey";
ALTER TABLE "CommunityMedia" DROP CONSTRAINT "CommunityMedia_ownerId_fkey";
ALTER TABLE "CommunityFollow" DROP CONSTRAINT "CommunityFollow_followerId_fkey";
ALTER TABLE "CommunityFollow" DROP CONSTRAINT "CommunityFollow_followingId_fkey";
ALTER TABLE "CommunityPostSave" DROP CONSTRAINT "CommunityPostSave_studentId_fkey";
ALTER TABLE "CommunityStory" DROP CONSTRAINT "CommunityStory_studentId_fkey";
ALTER TABLE "CommunityStoryView" DROP CONSTRAINT "CommunityStoryView_studentId_fkey";
ALTER TABLE "CommunityNotification" DROP CONSTRAINT "CommunityNotification_recipientId_fkey";
ALTER TABLE "CommunityNotification" DROP CONSTRAINT "CommunityNotification_actorId_fkey";
ALTER TABLE "CommunityPostLike" DROP CONSTRAINT "CommunityPostLike_studentId_fkey";
ALTER TABLE "CommunityPostComment" DROP CONSTRAINT "CommunityPostComment_studentId_fkey";

-- 4. Colunas que mudam de nome (studentId -> memberId): cria, preenche, torna obrigatória, remove a antiga
ALTER TABLE "CommunityPost" ADD COLUMN "memberId" TEXT;
UPDATE "CommunityPost" t SET "memberId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."studentId";
ALTER TABLE "CommunityPost" ALTER COLUMN "memberId" SET NOT NULL;
DROP INDEX "CommunityPost_studentId_createdAt_idx";
ALTER TABLE "CommunityPost" DROP COLUMN "studentId";
CREATE INDEX "CommunityPost_memberId_createdAt_idx" ON "CommunityPost"("memberId", "createdAt");

ALTER TABLE "CommunityPostLike" ADD COLUMN "memberId" TEXT;
UPDATE "CommunityPostLike" t SET "memberId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."studentId";
ALTER TABLE "CommunityPostLike" ALTER COLUMN "memberId" SET NOT NULL;
DROP INDEX "CommunityPostLike_postId_studentId_key";
ALTER TABLE "CommunityPostLike" DROP COLUMN "studentId";
CREATE UNIQUE INDEX "CommunityPostLike_postId_memberId_key" ON "CommunityPostLike"("postId", "memberId");

ALTER TABLE "CommunityPostComment" ADD COLUMN "memberId" TEXT;
UPDATE "CommunityPostComment" t SET "memberId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."studentId";
ALTER TABLE "CommunityPostComment" ALTER COLUMN "memberId" SET NOT NULL;
ALTER TABLE "CommunityPostComment" DROP COLUMN "studentId";

ALTER TABLE "CommunityPostSave" ADD COLUMN "memberId" TEXT;
UPDATE "CommunityPostSave" t SET "memberId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."studentId";
ALTER TABLE "CommunityPostSave" ALTER COLUMN "memberId" SET NOT NULL;
ALTER TABLE "CommunityPostSave" DROP CONSTRAINT "CommunityPostSave_pkey";
DROP INDEX "CommunityPostSave_studentId_createdAt_idx";
ALTER TABLE "CommunityPostSave" DROP COLUMN "studentId";
ALTER TABLE "CommunityPostSave" ADD CONSTRAINT "CommunityPostSave_pkey" PRIMARY KEY ("postId", "memberId");
CREATE INDEX "CommunityPostSave_memberId_createdAt_idx" ON "CommunityPostSave"("memberId", "createdAt");

ALTER TABLE "CommunityStory" ADD COLUMN "memberId" TEXT;
UPDATE "CommunityStory" t SET "memberId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."studentId";
ALTER TABLE "CommunityStory" ALTER COLUMN "memberId" SET NOT NULL;
DROP INDEX "CommunityStory_studentId_expiresAt_idx";
ALTER TABLE "CommunityStory" DROP COLUMN "studentId";
CREATE INDEX "CommunityStory_memberId_expiresAt_idx" ON "CommunityStory"("memberId", "expiresAt");

ALTER TABLE "CommunityStoryView" ADD COLUMN "memberId" TEXT;
UPDATE "CommunityStoryView" t SET "memberId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."studentId";
ALTER TABLE "CommunityStoryView" ALTER COLUMN "memberId" SET NOT NULL;
ALTER TABLE "CommunityStoryView" DROP CONSTRAINT "CommunityStoryView_pkey";
ALTER TABLE "CommunityStoryView" DROP COLUMN "studentId";
ALTER TABLE "CommunityStoryView" ADD CONSTRAINT "CommunityStoryView_pkey" PRIMARY KEY ("storyId", "memberId");

-- 5. Colunas que mantêm o nome: troca o id do aluno pelo id do perfil
UPDATE "CommunityMedia" t SET "ownerId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."ownerId";
UPDATE "CommunityFollow" t SET "followerId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."followerId";
UPDATE "CommunityFollow" t SET "followingId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."followingId";
UPDATE "CommunityNotification" t SET "recipientId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."recipientId";
UPDATE "CommunityNotification" t SET "actorId" = m."id" FROM "CommunityMember" m WHERE m."studentId" = t."actorId";

-- 6. Bio e foto saem do cadastro do aluno (já copiadas para o perfil)
DROP INDEX "Student_avatarMediaId_key";
ALTER TABLE "Student" DROP COLUMN "avatarMediaId", DROP COLUMN "bio";

-- 7. Novas chaves estrangeiras
ALTER TABLE "CommunityMember" ADD CONSTRAINT "CommunityMember_academyId_fkey" FOREIGN KEY ("academyId") REFERENCES "Academy"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityMember" ADD CONSTRAINT "CommunityMember_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityMember" ADD CONSTRAINT "CommunityMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityMember" ADD CONSTRAINT "CommunityMember_avatarMediaId_fkey" FOREIGN KEY ("avatarMediaId") REFERENCES "CommunityMedia"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "CommunityPost" ADD CONSTRAINT "CommunityPost_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityMedia" ADD CONSTRAINT "CommunityMedia_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityFollow" ADD CONSTRAINT "CommunityFollow_followerId_fkey" FOREIGN KEY ("followerId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityFollow" ADD CONSTRAINT "CommunityFollow_followingId_fkey" FOREIGN KEY ("followingId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPostSave" ADD CONSTRAINT "CommunityPostSave_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityStory" ADD CONSTRAINT "CommunityStory_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityStoryView" ADD CONSTRAINT "CommunityStoryView_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityNotification" ADD CONSTRAINT "CommunityNotification_recipientId_fkey" FOREIGN KEY ("recipientId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityNotification" ADD CONSTRAINT "CommunityNotification_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPostLike" ADD CONSTRAINT "CommunityPostLike_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CommunityPostComment" ADD CONSTRAINT "CommunityPostComment_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;
