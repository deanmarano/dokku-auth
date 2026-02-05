import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';
import {
  dokku,
  waitForHealthy,
} from './helpers';

/**
 * Protect / Unprotect E2E Tests
 *
 * Tests:
 * - auth:protect <app>        (auto-detect single frontend)
 * - auth:unprotect <app>      (auto-detect which frontend protects app)
 * - auth:frontend:protect <service> <app>   (explicit frontend)
 * - auth:frontend:unprotect <service> <app> (explicit frontend)
 * - Error cases: no frontend, app not found, idempotency
 */

const DIR_SERVICE = 'protect-dir-test';
const FRONTEND_SERVICE = 'protect-fe-test';
const TEST_APP = 'protect-test-app';
const TEST_APP_2 = 'protect-test-app2';

test.describe('Protect / Unprotect', () => {
  test.beforeAll(async () => {
    console.log('=== Setting up protect/unprotect test environment ===');

    // Create directory service
    try {
      dokku(`auth:create ${DIR_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    const dirHealthy = await waitForHealthy(DIR_SERVICE, 'directory');
    if (!dirHealthy) throw new Error('Directory service not healthy');

    // Create frontend service linked to directory
    try {
      dokku(`auth:frontend:create ${FRONTEND_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    try {
      dokku(`auth:frontend:use-directory ${FRONTEND_SERVICE} ${DIR_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already linked')) {
        console.log('use-directory result:', e.message);
      }
    }

    dokku(`auth:frontend:config ${FRONTEND_SERVICE} DOMAIN=protect-test.local`);

    try {
      dokku(`auth:frontend:apply ${FRONTEND_SERVICE}`);
    } catch (e: any) {
      console.log('frontend apply result:', e.message);
    }

    await waitForHealthy(FRONTEND_SERVICE, 'frontend', 120000);

    // Create test apps
    for (const app of [TEST_APP, TEST_APP_2]) {
      try {
        dokku(`apps:create ${app}`);
      } catch (e: any) {
        if (!e.stderr?.includes('already exists')) throw e;
      }
    }

    console.log('=== Setup complete ===');
  }, 600000);

  test.afterAll(async () => {
    console.log('=== Cleaning up ===');
    for (const app of [TEST_APP, TEST_APP_2]) {
      try { dokku(`auth:frontend:unprotect ${FRONTEND_SERVICE} ${app}`, { quiet: true }); } catch {}
      try { dokku(`apps:destroy ${app} --force`, { quiet: true }); } catch {}
    }
    try { dokku(`auth:frontend:destroy ${FRONTEND_SERVICE} -f`, { quiet: true }); } catch {}
    try { dokku(`auth:destroy ${DIR_SERVICE} -f`, { quiet: true }); } catch {}
  });

  // --- auth:frontend:protect / auth:frontend:unprotect (explicit service) ---

  test('auth:frontend:protect should protect an app', async () => {
    const output = dokku(`auth:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('Protecting');
    expect(output).toContain('now protected');
  });

  test('auth:frontend:protect should be idempotent', async () => {
    const output = dokku(`auth:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('already protected');
  });

  test('auth:frontend:info should show protected app', async () => {
    const info = dokku(`auth:frontend:info ${FRONTEND_SERVICE}`);
    expect(info).toContain(TEST_APP);
  });

  test('auth:frontend:unprotect should remove protection', async () => {
    const output = dokku(`auth:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('Removing protection');
    expect(output).toContain('removed');
  });

  test('auth:frontend:unprotect on non-protected app should be no-op', async () => {
    const output = dokku(`auth:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('not protected');
  });

  // --- auth:protect / auth:unprotect (auto-detect) ---

  test('auth:protect should auto-detect single frontend', async () => {
    const output = dokku(`auth:protect ${TEST_APP}`);
    expect(output).toContain('Protecting');
    expect(output).toContain(FRONTEND_SERVICE);
    expect(output).toContain('now protected');
  });

  test('auth:protect should be idempotent', async () => {
    const output = dokku(`auth:protect ${TEST_APP}`);
    expect(output).toContain('already protected');
  });

  test('auth:unprotect should auto-detect protecting frontend', async () => {
    const output = dokku(`auth:unprotect ${TEST_APP}`);
    expect(output).toContain('Removing protection');
    expect(output).toContain(FRONTEND_SERVICE);
    expect(output).toContain('removed');
  });

  test('auth:unprotect on non-protected app should be no-op', async () => {
    const output = dokku(`auth:unprotect ${TEST_APP}`);
    expect(output).toContain('not protected');
  });

  // --- Protect multiple apps ---

  test('should protect multiple apps on same frontend', async () => {
    dokku(`auth:protect ${TEST_APP}`);
    dokku(`auth:protect ${TEST_APP_2}`);

    const info = dokku(`auth:frontend:info ${FRONTEND_SERVICE}`);
    expect(info).toContain(TEST_APP);
    expect(info).toContain(TEST_APP_2);

    // Cleanup
    dokku(`auth:unprotect ${TEST_APP}`);
    dokku(`auth:unprotect ${TEST_APP_2}`);
  });

  // --- Error cases ---

  test('auth:protect should fail for non-existent app', async () => {
    try {
      dokku(`auth:protect no-such-app-xyz`, { quiet: true });
      expect(true).toBe(false); // should not reach
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('auth:frontend:protect should fail for non-existent frontend', async () => {
    try {
      dokku(`auth:frontend:protect no-such-frontend ${TEST_APP}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('auth:frontend:protect should fail for non-existent app', async () => {
    try {
      dokku(`auth:frontend:protect ${FRONTEND_SERVICE} no-such-app-xyz`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });
});
