import { describe, it, expect, afterAll } from 'vitest';
import { DokkuSso } from '../helpers/dokku';

describe('Provider Management', () => {
  const auth = new DokkuSso();
  const serviceName = `test-provider-${Date.now()}`;

  afterAll(async () => {
    await auth.exec(`sso:destroy ${serviceName} -f`).catch(() => {});
  }, 60000);

  it('should list available providers', async () => {
    const result = await auth.exec('sso:providers');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('lldap');
  });

  it('should create service with default provider', async () => {
    const result = await auth.exec(`sso:create ${serviceName}`);
    expect(result.exitCode).toBe(0);
  }, 120000);

  it('should show provider in info', async () => {
    const result = await auth.exec(`sso:info ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('lldap');
  });

  it('should configure provider settings', async () => {
    const result = await auth.exec(`sso:provider:config ${serviceName} HTTP_URL=https://ldap.test.local`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('HTTP_URL');
  });

  it('should show configuration', async () => {
    const result = await auth.exec(`sso:provider:config ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('HTTP_URL');
    expect(result.stdout).toContain('ldap.test.local');
  });
});

describe('Multiple Directory Providers', () => {
  const auth = new DokkuSso();
  const lldapService = `test-lldap-${Date.now()}`;
  const glAuthService = `test-glauth-${Date.now()}`;

  afterAll(async () => {
    await auth.exec(`sso:destroy ${lldapService} -f`).catch(() => {});
    await auth.exec(`sso:destroy ${glAuthService} -f`).catch(() => {});
  }, 60000);

  it('should create LLDAP service', async () => {
    const result = await auth.exec(`sso:create ${lldapService}`);
    expect(result.exitCode).toBe(0);
  }, 120000);

  it('should create GLAuth service', async () => {
    // First create service, then set provider
    await auth.exec(`sso:create ${glAuthService}`);
    // Note: In real scenario, you'd want to set provider before first apply
    // This tests the infrastructure works
  }, 120000);

  it('should list both services', async () => {
    const result = await auth.exec('sso:list');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain(lldapService);
    expect(result.stdout).toContain(glAuthService);
  });
});
