-- Credenciais de aparelho para entrar com biometria (só adiciona uma tabela).
-- CreateTable
CREATE TABLE "DeviceCredential" (
    "id" TEXT NOT NULL,
    "studentId" TEXT,
    "userId" TEXT,
    "secretHash" TEXT NOT NULL,
    "label" VARCHAR(80),
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "lastUsedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeviceCredential_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "DeviceCredential_owner_check" CHECK (("studentId" IS NULL) <> ("userId" IS NULL))
);

-- CreateIndex
CREATE UNIQUE INDEX "DeviceCredential_secretHash_key" ON "DeviceCredential"("secretHash");

-- CreateIndex
CREATE INDEX "DeviceCredential_studentId_idx" ON "DeviceCredential"("studentId");

-- CreateIndex
CREATE INDEX "DeviceCredential_userId_idx" ON "DeviceCredential"("userId");

-- AddForeignKey
ALTER TABLE "DeviceCredential" ADD CONSTRAINT "DeviceCredential_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DeviceCredential" ADD CONSTRAINT "DeviceCredential_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

