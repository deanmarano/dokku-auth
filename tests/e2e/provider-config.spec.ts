import { test, expect } from '@playwright/test';
import {
  dokku,
  waitForHealthy,
} from './helpers';

/**
 * Provider Configuration E2E Tests
 *
 * Tests:
 * - sso:provider:config      (get/set directory provider config)
 * - sso:provider:apply       (apply config changes, recreate container)
 * - sso:frontend:config      (get/set frontend config)
 * - sso:frontend:provider:apply (apply frontend config changes)
 * - Sensitive value masking
 * - Invalid format rejection
 */

const DIR_SERVICE = 'provider-cfg-test';
const FRONTEND_SERVICE = 'provider-fe-cfg-test';

test.describe('Provider Configuration', () => {
  test.beforeAll(async () => {
    console.log('=== Setting up provider config test environment ===');

    // Create directory service
    try {
      dokku(`sso:create ${DIR_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    const dirHealthy = await waitForHealthy(DIR_SERVICE, 'directory');
    if (!dirHealthy) throw new Error('Directory service not healthy');

    console.log('=== Setup complete ===');
  }, 300000);

  test.afterAll(async () => {
    console.log('=== Cleaning up ===');
    try { dokku(`sso:frontend:destroy ${FRONTEND_SERVICE} -f`, { quiet: true }); } catch {}
    try { dokku(`sso:destroy ${DIR_SERVICE} -f`, { quiet: true }); } catch {}
  });

  // --- Directory provider:config ---

  test('provider:config should show current config', async () => {
    const output = dokku(`sso:provider:config ${DIR_SERVICE}`);
    expect(output).toContain('Configuration for');
    expect(output).toContain(DIR_SERVICE);
  });

  test('provider:config should set a config value', async () => {
    const output = dokku(`sso:provider:config ${DIR_SERVICE} LLDAP_LDAP_USER_DN=ou=custom,dc=test,dc=local`);
    expect(output).toContain('Setting configuration');
    expect(output).toContain('LLDAP_LDAP_USER_DN=ou=custom,dc=test,dc=local');
    expect(output).toContain('provider:apply');
  });

  test('provider:config should persist values', async () => {
    dokku(`sso:provider:config ${DIR_SERVICE} TZ=America/Chicago`);
    const output = dokku(`sso:provider:config ${DIR_SERVICE}`);
    expect(output).toContain('TZ=America/Chicago');
  });

  test('provider:config should mask sensitive values', async () => {
    dokku(`sso:provider:config ${DIR_SERVICE} JWT_SECRET=supersecretvalue123`);
    const output = dokku(`sso:provider:config ${DIR_SERVICE}`);
    // Sensitive values should be masked with *** in display
    expect(output).toContain('JWT_SECRET=');
    expect(output).not.toContain('supersecretvalue123');
    expect(output).toContain('***');
  });

  test('provider:config should reject invalid format', async () => {
    try {
      const output = dokku(`sso:provider:config ${DIR_SERVICE} BADFORMAT`);
      // The command doesn't exit non-zero for bad format, it prints a warning
      expect(output).toContain('Invalid format');
    } catch (e: any) {
      expect(e.stderr || e.stdout).toContain('Invalid format');
    }
  });

  test('provider:config should set multiple values at once', async () => {
    const output = dokku(`sso:provider:config ${DIR_SERVICE} KEY_A=value1 KEY_B=value2`);
    expect(output).toContain('KEY_A=value1');
    expect(output).toContain('KEY_B=value2');

    const show = dokku(`sso:provider:config ${DIR_SERVICE}`);
    expect(show).toContain('KEY_A=value1');
    expect(show).toContain('KEY_B=value2');
  });

  // --- Directory provider:apply ---

  test('provider:apply should recreate directory container', async () => {
    const output = dokku(`sso:provider:apply ${DIR_SERVICE}`);
    expect(output).toContain('Applying configuration');
    expect(output).toContain('Validating');
    expect(output).toContain('Creating container');
    expect(output).toContain('applied successfully');
  });

  test('service should be healthy after apply', async () => {
    const healthy = await waitForHealthy(DIR_SERVICE, 'directory');
    expect(healthy).toBe(true);
  });

  test('provider:apply on non-existent service should fail', async () => {
    try {
      dokku('sso:provider:apply no-such-service', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  // --- Frontend config ---

  test('frontend:config lifecycle', async () => {
    // Create frontend
    try {
      dokku(`sso:frontend:create ${FRONTEND_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    // Set config values
    const setOutput = dokku(`sso:frontend:config ${FRONTEND_SERVICE} DOMAIN=cfg-test.local`);
    expect(setOutput).toContain('Setting configuration');
    expect(setOutput).toContain('DOMAIN=cfg-test.local');

    // Read them back
    const showOutput = dokku(`sso:frontend:config ${FRONTEND_SERVICE}`);
    expect(showOutput).toContain('DOMAIN=cfg-test.local');
  });

  test('frontend:config should mask sensitive values', async () => {
    dokku(`sso:frontend:config ${FRONTEND_SERVICE} SESSION_SECRET=very-secret-session-key`);
    const output = dokku(`sso:frontend:config ${FRONTEND_SERVICE}`);
    expect(output).toContain('SESSION_SECRET=');
    expect(output).not.toContain('very-secret-session-key');
    expect(output).toContain('***');
  });

  // --- Frontend provider:apply ---

  test('frontend:provider:apply should create container', async () => {
    // Link to directory first
    try {
      dokku(`sso:frontend:use-directory ${FRONTEND_SERVICE} ${DIR_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already linked')) {
        console.log('use-directory result:', e.message);
      }
    }

    const output = dokku(`sso:frontend:apply ${FRONTEND_SERVICE}`);
    expect(output).toContain('Applying configuration');
    expect(output).toContain('Creating container');
    expect(output).toContain('applied successfully');
  });

  test('frontend should be running after apply', async () => {
    const healthy = await waitForHealthy(FRONTEND_SERVICE, 'frontend', 120000);
    expect(healthy).toBe(true);
  });

  test('frontend:provider:apply on non-existent service should fail', async () => {
    try {
      dokku('sso:frontend:apply no-such-frontend', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  // --- Re-apply preserves state ---

  test('provider:apply should refresh linked apps', async () => {
    // Link an app
    const app = 'cfg-reapply-test';
    try {
      dokku(`apps:create ${app}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    dokku(`sso:link ${DIR_SERVICE} ${app}`);

    // Re-apply — should refresh linked apps
    const output = dokku(`sso:provider:apply ${DIR_SERVICE}`);
    expect(output).toContain('Refreshing linked apps');
    expect(output).toContain(app);

    // Cleanup
    try { dokku(`sso:unlink ${DIR_SERVICE} ${app}`, { quiet: true }); } catch {}
    try { dokku(`apps:destroy ${app} --force`, { quiet: true }); } catch {}
  });
});
