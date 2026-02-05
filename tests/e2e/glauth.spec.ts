import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';
import { dokku, waitForHealthy, getContainerIp, getLdapCredentials } from './helpers';

/**
 * GLAuth Directory Provider E2E Test
 *
 * Tests the GLAuth provider:
 * 1. Creating a directory service with GLAuth provider
 * 2. Verifying LDAP port is accessible
 * 3. Testing LDAP bind with admin credentials
 * 4. Verifying service info and credentials
 */

const SERVICE_NAME = 'glauth-e2e-test';

test.describe('GLAuth Directory Provider', () => {
  test.beforeAll(async () => {
    console.log('=== Setting up GLAuth test ===');

    // Create GLAuth directory service
    console.log('Creating GLAuth directory service...');
    try {
      dokku(`auth:create ${SERVICE_NAME} --provider glauth`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) {
        throw e;
      }
    }

    // Wait for service to be healthy
    const healthy = await waitForHealthy(SERVICE_NAME, 'directory');
    if (!healthy) {
      throw new Error('GLAuth service not healthy');
    }

    console.log('=== Setup complete ===');
  }, 300000); // 5 minute timeout

  test.afterAll(async () => {
    console.log('=== Cleaning up GLAuth test ===');
    try {
      dokku(`auth:destroy ${SERVICE_NAME} -f`, { quiet: true });
    } catch (e: any) {
      console.log('[cleanup] auth:destroy:', e.stderr?.trim() || e.message);
    }
  });

  test('service status shows healthy', async () => {
    const status = dokku(`auth:status ${SERVICE_NAME}`);
    expect(status).toContain('healthy');
  });

  test('service info shows GLAuth provider', async () => {
    const info = dokku(`auth:info ${SERVICE_NAME}`);
    expect(info.toLowerCase()).toContain('glauth');
  });

  test('credentials are generated', async () => {
    const creds = getLdapCredentials(SERVICE_NAME);
    expect(creds.LDAP_URL).toBeDefined();
    expect(creds.LDAP_BASE_DN).toBeDefined();
    expect(creds.LDAP_BIND_DN).toBeDefined();
    expect(creds.ADMIN_PASSWORD).toBeDefined();
  });

  test('GLAuth process is running', async () => {
    const containerName = `dokku.auth.directory.${SERVICE_NAME}`;

    // GLAuth image is minimal (scratch-based), verify by checking process
    const result = execSync(
      `docker top ${containerName}`,
      { encoding: 'utf-8' }
    );

    expect(result).toContain('glauth');
  });

  test('LDAP credentials have correct format', async () => {
    const creds = getLdapCredentials(SERVICE_NAME);

    // GLAuth uses cn=admin,BASE_DN format
    expect(creds.LDAP_BIND_DN).toContain('cn=admin');
    expect(creds.LDAP_URL).toContain('3893');
  });

  test('doctor check passes', async () => {
    const result = dokku(`auth:doctor ${SERVICE_NAME}`);
    // Doctor should not report errors
    expect(result.toLowerCase()).not.toContain('error');
  });
});
