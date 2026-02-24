import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { DokkuSso, createTestApp, destroyTestApp } from '../helpers/dokku';

describe('Frontend Service (Authelia)', () => {
  const auth = new DokkuSso();
  const serviceName = `test-frontend-${Date.now()}`;
  const directoryName = `test-dir-${Date.now()}`;
  const testAppName = `test-protect-${Date.now()}`;

  beforeAll(async () => {
    // Create a directory service and a test app for protect/unprotect tests
    await auth.exec(`sso:create ${directoryName}`);
    await createTestApp(testAppName);
  }, 120000);

  afterAll(async () => {
    await auth.exec(`sso:frontend:destroy ${serviceName} -f`).catch(() => {});
    await auth.exec(`sso:destroy ${directoryName} -f`).catch(() => {});
    await destroyTestApp(testAppName).catch(() => {});
  }, 60000);

  it('should create a frontend service', async () => {
    const result = await auth.exec(`sso:frontend:create ${serviceName}`);
    if (result.exitCode !== 0) {
      console.log('stdout:', result.stdout);
      console.log('stderr:', result.stderr);
    }
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Frontend service');
    expect(result.stdout).toContain('created');
  }, 120000);

  it('should list frontend services with running status', async () => {
    const result = await auth.exec('sso:frontend:list');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain(serviceName);
    expect(result.stdout).toContain('running');
  });

  it('should show frontend status as running', async () => {
    const result = await auth.exec(`sso:frontend:status ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('running');
  });

  it('should show frontend info with running status', async () => {
    const result = await auth.exec(`sso:frontend:info ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Authelia');
    expect(result.stdout).toContain('Dokku App');
    expect(result.stdout).toContain('running');
  });

  it('should show frontend logs', async () => {
    const result = await auth.exec(`sso:frontend:logs ${serviceName} --tail 5`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout.length).toBeGreaterThan(0);
  });

  it('should configure domain', async () => {
    const result = await auth.exec(`sso:frontend:config ${serviceName} DOMAIN=auth.test.local`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('DOMAIN=auth.test.local');
  });

  it('should link to directory service', async () => {
    const result = await auth.exec(`sso:frontend:use-directory ${serviceName} ${directoryName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Directory configured');
  });

  it('should protect an app', async () => {
    const result = await auth.exec(`sso:frontend:protect ${serviceName} ${testAppName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('protected');
  });

  it('should show protected app in info', async () => {
    const result = await auth.exec(`sso:frontend:info ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain(testAppName);
  });

  it('should show protected app in list count', async () => {
    const result = await auth.exec('sso:frontend:list');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('protected: 1');
  });

  it('should unprotect an app', async () => {
    const result = await auth.exec(`sso:frontend:unprotect ${serviceName} ${testAppName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('removed');
  });

  it('should show no protected apps after unprotect', async () => {
    const result = await auth.exec(`sso:frontend:info ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('(none)');
  });

  it('should enable OIDC', async () => {
    const result = await auth.exec(`sso:oidc:enable ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('OIDC enabled');
  });

  it('should add OIDC client', async () => {
    const result = await auth.exec(`sso:oidc:add-client ${serviceName} test-app test-secret https://app.test.local/callback`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Client added');
    expect(result.stdout).toContain('test-app');
  });

  it('should list OIDC clients', async () => {
    const result = await auth.exec(`sso:oidc:list ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('test-app');
  });

  it('should remove OIDC client', async () => {
    const result = await auth.exec(`sso:oidc:remove-client ${serviceName} test-app`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Client removed');
  });

  it('should disable OIDC', async () => {
    const result = await auth.exec(`sso:oidc:disable ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('OIDC disabled');
  });

  it('should destroy frontend service', async () => {
    const result = await auth.exec(`sso:frontend:destroy ${serviceName} -f`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('destroyed');
  });
});

describe('Frontend Service - Adopt Existing App', () => {
  const auth = new DokkuSso();
  const serviceName = `test-adopt-${Date.now()}`;
  const appName = `test-adopt-app-${Date.now()}`;

  beforeAll(async () => {
    // Create a Dokku app to adopt
    await createTestApp(appName);
  }, 30000);

  afterAll(async () => {
    await auth.exec(`sso:frontend:destroy ${serviceName} -f --keep-app`).catch(() => {});
    await destroyTestApp(appName).catch(() => {});
  }, 60000);

  it('should adopt an existing Dokku app', async () => {
    const result = await auth.exec(`sso:frontend:create ${serviceName} --app ${appName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Adopting existing Dokku app');
    expect(result.stdout).toContain(appName);
    expect(result.stdout).toContain('created');
  });

  it('should show adopted app in list', async () => {
    const result = await auth.exec('sso:frontend:list');
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain(serviceName);
  });

  it('should show adopted app in info', async () => {
    const result = await auth.exec(`sso:frontend:info ${serviceName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Dokku App');
  });

  it('should allow re-adopting into existing service', async () => {
    const result = await auth.exec(`sso:frontend:create ${serviceName} --app ${appName}`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Adopting existing Dokku app');
  });

  it('should fail to adopt a non-existent app', async () => {
    const bogusService = `test-bogus-${Date.now()}`;
    const result = await auth.exec(`sso:frontend:create ${bogusService} --app non-existent-app-xyz`);
    expect(result.exitCode).not.toBe(0);
    // Clean up the service dir that was created before the error
    await auth.exec(`sso:frontend:destroy ${bogusService} -f`).catch(() => {});
  });

  it('should destroy with --keep-app preserving the Dokku app', async () => {
    const result = await auth.exec(`sso:frontend:destroy ${serviceName} -f --keep-app`);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('Keeping Dokku app');
    expect(result.stdout).toContain('destroyed');
  });
});
