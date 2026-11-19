import {
  deviceCredentialExpiry,
  deviceSecretMatches,
  generateDeviceSecret,
  hashDeviceSecret,
} from './device-credential';

describe('credencial de aparelho', () => {
  it('gera segredos aleatórios de 64 hex', () => {
    const a = generateDeviceSecret();
    expect(a).toMatch(/^[a-f0-9]{64}$/);
    expect(generateDeviceSecret()).not.toBe(a);
  });

  it('confere o segredo pelo hash, sem guardar o segredo', () => {
    const secret = generateDeviceSecret();
    const hash = hashDeviceSecret(secret);
    expect(hash).not.toBe(secret);
    expect(deviceSecretMatches(secret, hash)).toBe(true);
    expect(deviceSecretMatches(generateDeviceSecret(), hash)).toBe(false);
  });

  it('recusa valores malformados sem lançar erro', () => {
    expect(deviceSecretMatches('abc', hashDeviceSecret('abc'))).toBe(false);
    expect(deviceSecretMatches(generateDeviceSecret(), 'nao-e-hash')).toBe(false);
  });

  it('expira 90 dias depois', () => {
    expect(deviceCredentialExpiry(new Date('2026-01-01T00:00:00Z')).toISOString()).toBe('2026-04-01T00:00:00.000Z');
  });
});
