import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';
import {
  USE_SUDO,
  dokku,
  waitForHealthy,
} from './helpers';

/**
 * Error Handling E2E Tests
 *
 * Tests:
 * - Operations on non-existent services
 * - destroy without -f when apps are linked / apps are protected
 * - Invalid service names
 * - Status exit codes (0=healthy, 1=degraded, 2=down/missing)
 * - Missing arguments
 * - sso:create duplicate detection
 */

const DIR_SERVICE = 'error-dir-test';
const FRONTEND_SERVICE = 'error-fe-test';
const TEST_APP = 'error-test-app';

test.describe('Error Handling', () => {
  test.beforeAll(async () => {
    console.log('=== Setting up error handling test environment ===');

    try {
      dokku(`sso:create ${DIR_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    const healthy = await waitForHealthy(DIR_SERVICE, 'directory');
    if (!healthy) throw new Error('Directory service not healthy');

    try {
      dokku(`apps:create ${TEST_APP}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    console.log('=== Setup complete ===');
  }, 300000);

  test.afterAll(async () => {
    console.log('=== Cleaning up ===');
    try { dokku(`sso:unlink ${DIR_SERVICE} ${TEST_APP}`, { quiet: true }); } catch {}
    try { dokku(`apps:destroy ${TEST_APP} --force`, { quiet: true }); } catch {}
    try { dokku(`sso:frontend:destroy ${FRONTEND_SERVICE} -f`, { quiet: true }); } catch {}
    try { dokku(`sso:destroy ${DIR_SERVICE} -f`, { quiet: true }); } catch {}
  });

  // --- Non-existent service ---

  test('sso:info on non-existent service should fail', async () => {
    try {
      dokku('sso:info nonexistent-svc-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('sso:status on non-existent service should exit 2', async () => {
    const cmd = USE_SUDO
      ? 'sudo dokku sso:status nonexistent-svc-xyz'
      : 'dokku sso:status nonexistent-svc-xyz';
    try {
      execSync(cmd, { encoding: 'utf-8', stdio: 'pipe' });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.status).toBe(2);
    }
  });

  test('sso:credentials on non-existent service should fail', async () => {
    try {
      dokku('sso:credentials nonexistent-svc-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('sso:destroy on non-existent service should fail', async () => {
    try {
      dokku('sso:destroy nonexistent-svc-xyz -f', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('sso:link on non-existent service should fail', async () => {
    try {
      dokku(`sso:link nonexistent-svc-xyz ${TEST_APP}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('sso:frontend:info on non-existent frontend should fail', async () => {
    try {
      dokku('sso:frontend:info nonexistent-fe-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  // --- Status exit codes ---

  test('sso:status should exit 0 for healthy service', async () => {
    const cmd = USE_SUDO
      ? `sudo dokku sso:status ${DIR_SERVICE}`
      : `dokku sso:status ${DIR_SERVICE}`;
    const result = execSync(cmd, { encoding: 'utf-8' });
    expect(result).toContain('healthy');
    // Exit code 0 implied by no throw
  });

  test('sso:status -q should suppress output', async () => {
    const cmd = USE_SUDO
      ? `sudo dokku sso:status ${DIR_SERVICE} -q`
      : `dokku sso:status ${DIR_SERVICE} -q`;
    const result = execSync(cmd, { encoding: 'utf-8' });
    // Quiet mode: output should be empty or minimal
    expect(result.trim()).toBe('');
  });

  test('sso:status -q on non-existent should suppress error', async () => {
    const cmd = USE_SUDO
      ? 'sudo dokku sso:status nonexistent-svc-xyz -q'
      : 'dokku sso:status nonexistent-svc-xyz -q';
    try {
      execSync(cmd, { encoding: 'utf-8', stdio: 'pipe' });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.status).toBe(2);
      // Quiet mode: stderr should be empty
      expect(e.stderr?.trim() || '').toBe('');
    }
  });

  // --- Duplicate creation ---

  test('sso:create should fail if service already exists', async () => {
    try {
      dokku(`sso:create ${DIR_SERVICE}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('already exists');
    }
  });

  // --- Invalid service names ---

  test('sso:create should reject uppercase names', async () => {
    try {
      dokku('sso:create UpperCase', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('must start with a letter');
    }
  });

  test('sso:create should reject names starting with number', async () => {
    try {
      dokku('sso:create 123invalid', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('must start with a letter');
    }
  });

  test('sso:create should reject names with special characters', async () => {
    try {
      dokku('sso:create bad_name!', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('must start with a letter');
    }
  });

  // --- Missing arguments ---

  test('sso:create with no args should show usage', async () => {
    try {
      dokku('sso:create', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  test('sso:link with no app should show usage', async () => {
    try {
      dokku(`sso:link ${DIR_SERVICE}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  test('sso:protect with no args should show usage', async () => {
    try {
      dokku('sso:protect', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  test('sso:unprotect with no args should show usage', async () => {
    try {
      dokku('sso:unprotect', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  // --- destroy with linked apps (no -f) ---

  test('sso:destroy without -f should fail when apps are linked', async () => {
    // Link an app
    dokku(`sso:link ${DIR_SERVICE} ${TEST_APP}`);

    // Try destroy without -f — should fail (requires interactive confirm AND has linked apps)
    try {
      // Use execSync directly to capture exit code; stdin is not a TTY so confirmation will fail
      const cmd = USE_SUDO
        ? `sudo dokku sso:destroy ${DIR_SERVICE}`
        : `dokku sso:destroy ${DIR_SERVICE}`;
      execSync(cmd, { encoding: 'utf-8', stdio: 'pipe', timeout: 10000 });
      expect(true).toBe(false);
    } catch (e: any) {
      // Should mention linked apps
      expect(e.stderr).toContain('linked apps');
      expect(e.stderr).toContain(TEST_APP);
    }
  });

  test('sso:destroy with -f should succeed despite linked apps', async () => {
    // Re-create service for subsequent tests to work in afterAll
    // But first verify -f works
    const output = dokku(`sso:destroy ${DIR_SERVICE} -f`);
    expect(output).toContain('Destroying');
    expect(output).toContain('destroyed');

    // Re-create for cleanup symmetry
    dokku(`sso:create ${DIR_SERVICE}`);
    await waitForHealthy(DIR_SERVICE, 'directory');
  });

  // --- Frontend destroy with protected apps ---

  test('sso:frontend:destroy without -f should fail when apps protected', async () => {
    // Create frontend
    try {
      dokku(`sso:frontend:create ${FRONTEND_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    try {
      dokku(`sso:frontend:use-directory ${FRONTEND_SERVICE} ${DIR_SERVICE}`);
    } catch {}

    dokku(`sso:frontend:config ${FRONTEND_SERVICE} DOMAIN=err-test.local`);

    try {
      dokku(`sso:frontend:apply ${FRONTEND_SERVICE}`);
    } catch {}

    await waitForHealthy(FRONTEND_SERVICE, 'frontend', 120000);

    // Protect an app
    dokku(`sso:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);

    // Try destroy without -f
    try {
      const cmd = USE_SUDO
        ? `sudo dokku sso:frontend:destroy ${FRONTEND_SERVICE}`
        : `dokku sso:frontend:destroy ${FRONTEND_SERVICE}`;
      execSync(cmd, { encoding: 'utf-8', stdio: 'pipe', timeout: 10000 });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('protected apps');
    }

    // Cleanup: unprotect so afterAll can destroy
    try { dokku(`sso:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`, { quiet: true }); } catch {}
  });

  // --- Unknown command ---

  test('unknown sso subcommand should fail with help hint', async () => {
    try {
      dokku('sso:nonexistent-command-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Unknown command');
      expect(e.stderr).toContain('sso:help');
    }
  });
});
