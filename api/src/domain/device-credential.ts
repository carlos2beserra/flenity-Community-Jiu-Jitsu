import { createHash, randomBytes, timingSafeEqual } from 'crypto';

/** Validade de uma credencial de biometria; renovada a cada uso (expiração deslizante). */
export const DEVICE_CREDENTIAL_TTL_DAYS = 90;

/** Segredo de 256 bits, mostrado ao app uma única vez. */
export function generateDeviceSecret(): string {
  return randomBytes(32).toString('hex');
}

export function hashDeviceSecret(secret: string): string {
  return createHash('sha256').update(secret).digest('hex');
}

export function deviceSecretMatches(secret: string, storedHash: string): boolean {
  if (!/^[a-f0-9]{64}$/.test(secret) || !/^[a-f0-9]{64}$/.test(storedHash)) return false;
  return timingSafeEqual(Buffer.from(hashDeviceSecret(secret), 'hex'), Buffer.from(storedHash, 'hex'));
}

export function deviceCredentialExpiry(from: Date): Date {
  return new Date(from.getTime() + DEVICE_CREDENTIAL_TTL_DAYS * 24 * 60 * 60 * 1000);
}
