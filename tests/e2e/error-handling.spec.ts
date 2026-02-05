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
 * - auth:create duplicate detection
 */

const DIR_SERVICE = 'error-dir-test';
const FRONTEND_SERVICE = 'error-fe-test';
const TEST_APP = 'error-test-app';

test.describe('Error Handling', () => {
  test.beforeAll(async () => {
    console.log('=== Setting up error handling test environment ===');

    try {
      dokku(`auth:create ${DIR_SERVICE}`);
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
    try { dokku(`auth:unlink ${DIR_SERVICE} ${TEST_APP}`, { quiet: true }); } catch {}
    try { dokku(`apps:destroy ${TEST_APP} --force`, { quiet: true }); } catch {}
    try { dokku(`auth:frontend:destroy ${FRONTEND_SERVICE} -f`, { quiet: true }); } catch {}
    try { dokku(`auth:destroy ${DIR_SERVICE} -f`, { quiet: true }); } catch {}
  });

  // --- Non-existent service ---

  test('auth:info on non-existent service should fail', async () => {
    try {
      dokku('auth:info nonexistent-svc-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('auth:status on non-existent service should exit 2', async () => {
    const cmd = USE_SUDO
      ? 'sudo dokku auth:status nonexistent-svc-xyz'
      : 'dokku auth:status nonexistent-svc-xyz';
    try {
      execSync(cmd, { encoding: 'utf-8', stdio: 'pipe' });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.status).toBe(2);
    }
  });

  test('auth:credentials on non-existent service should fail', async () => {
    try {
      dokku('auth:credentials nonexistent-svc-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('auth:destroy on non-existent service should fail', async () => {
    try {
      dokku('auth:destroy nonexistent-svc-xyz -f', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('auth:link on non-existent service should fail', async () => {
    try {
      dokku(`auth:link nonexistent-svc-xyz ${TEST_APP}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('auth:frontend:info on non-existent frontend should fail', async () => {
    try {
      dokku('auth:frontend:info nonexistent-fe-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  // --- Status exit codes ---

  test('auth:status should exit 0 for healthy service', async () => {
    const cmd = USE_SUDO
      ? `sudo dokku auth:status ${DIR_SERVICE}`
      : `dokku auth:status ${DIR_SERVICE}`;
    const result = execSync(cmd, { encoding: 'utf-8' });
    expect(result).toContain('healthy');
    // Exit code 0 implied by no throw
  });

  test('auth:status -q should suppress output', async () => {
    const cmd = USE_SUDO
      ? `sudo dokku auth:status ${DIR_SERVICE} -q`
      : `dokku auth:status ${DIR_SERVICE} -q`;
    const result = execSync(cmd, { encoding: 'utf-8' });
    // Quiet mode: output should be empty or minimal
    expect(result.trim()).toBe('');
  });

  test('auth:status -q on non-existent should suppress error', async () => {
    const cmd = USE_SUDO
      ? 'sudo dokku auth:status nonexistent-svc-xyz -q'
      : 'dokku auth:status nonexistent-svc-xyz -q';
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

  test('auth:create should fail if service already exists', async () => {
    try {
      dokku(`auth:create ${DIR_SERVICE}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('already exists');
    }
  });

  // --- Invalid service names ---

  test('auth:create should reject uppercase names', async () => {
    try {
      dokku('auth:create UpperCase', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('must start with a letter');
    }
  });

  test('auth:create should reject names starting with number', async () => {
    try {
      dokku('auth:create 123invalid', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('must start with a letter');
    }
  });

  test('auth:create should reject names with special characters', async () => {
    try {
      dokku('auth:create bad_name!', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('must start with a letter');
    }
  });

  // --- Missing arguments ---

  test('auth:create with no args should show usage', async () => {
    try {
      dokku('auth:create', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  test('auth:link with no app should show usage', async () => {
    try {
      dokku(`auth:link ${DIR_SERVICE}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  test('auth:protect with no args should show usage', async () => {
    try {
      dokku('auth:protect', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  test('auth:unprotect with no args should show usage', async () => {
    try {
      dokku('auth:unprotect', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Usage');
    }
  });

  // --- destroy with linked apps (no -f) ---

  test('auth:destroy without -f should fail when apps are linked', async () => {
    // Link an app
    dokku(`auth:link ${DIR_SERVICE} ${TEST_APP}`);

    // Try destroy without -f — should fail (requires interactive confirm AND has linked apps)
    try {
      // Use execSync directly to capture exit code; stdin is not a TTY so confirmation will fail
      const cmd = USE_SUDO
        ? `sudo dokku auth:destroy ${DIR_SERVICE}`
        : `dokku auth:destroy ${DIR_SERVICE}`;
      execSync(cmd, { encoding: 'utf-8', stdio: 'pipe', timeout: 10000 });
      expect(true).toBe(false);
    } catch (e: any) {
      // Should mention linked apps
      expect(e.stderr).toContain('linked apps');
      expect(e.stderr).toContain(TEST_APP);
    }
  });

  test('auth:destroy with -f should succeed despite linked apps', async () => {
    // Re-create service for subsequent tests to work in afterAll
    // But first verify -f works
    const output = dokku(`auth:destroy ${DIR_SERVICE} -f`);
    expect(output).toContain('Destroying');
    expect(output).toContain('destroyed');

    // Re-create for cleanup symmetry
    dokku(`auth:create ${DIR_SERVICE}`);
    await waitForHealthy(DIR_SERVICE, 'directory');
  });

  // --- Frontend destroy with protected apps ---

  test('auth:frontend:destroy without -f should fail when apps protected', async () => {
    // Create frontend
    try {
      dokku(`auth:frontend:create ${FRONTEND_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    try {
      dokku(`auth:frontend:use-directory ${FRONTEND_SERVICE} ${DIR_SERVICE}`);
    } catch {}

    dokku(`auth:frontend:config ${FRONTEND_SERVICE} DOMAIN=err-test.local`);

    try {
      dokku(`auth:frontend:apply ${FRONTEND_SERVICE}`);
    } catch {}

    await waitForHealthy(FRONTEND_SERVICE, 'frontend', 120000);

    // Protect an app
    dokku(`auth:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);

    // Try destroy without -f
    try {
      const cmd = USE_SUDO
        ? `sudo dokku auth:frontend:destroy ${FRONTEND_SERVICE}`
        : `dokku auth:frontend:destroy ${FRONTEND_SERVICE}`;
      execSync(cmd, { encoding: 'utf-8', stdio: 'pipe', timeout: 10000 });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('protected apps');
    }

    // Cleanup: unprotect so afterAll can destroy
    try { dokku(`auth:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`, { quiet: true }); } catch {}
  });

  // --- Unknown command ---

  test('unknown auth subcommand should fail with help hint', async () => {
    try {
      dokku('auth:nonexistent-command-xyz', { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('Unknown command');
      expect(e.stderr).toContain('auth:help');
    }
  });
});
