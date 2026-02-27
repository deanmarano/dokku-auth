import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';
import {
  dokku,
  waitForHealthy,
} from './helpers';

/**
 * Protect / Unprotect / Refresh E2E Tests
 *
 * Tests:
 * - sso:protect <app>        (auto-detect single frontend)
 * - sso:unprotect <app>      (auto-detect which frontend protects app)
 * - sso:frontend:protect <service> <app>   (explicit frontend)
 * - sso:frontend:unprotect <service> <app> (explicit frontend)
 * - sso:frontend:refresh <service>         (re-apply all links)
 * - Error cases: no frontend, app not found, idempotency
 */

const DIR_SERVICE = 'protect-dir-test';
const FRONTEND_SERVICE = 'protect-fe-test';
const TEST_APP = 'protect-test-app';
const TEST_APP_2 = 'protect-test-app2';

test.describe('Protect / Unprotect / Refresh', () => {
  test.beforeAll(async () => {
    console.log('=== Setting up protect/unprotect test environment ===');

    // Create directory service
    try {
      dokku(`sso:create ${DIR_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    const dirHealthy = await waitForHealthy(DIR_SERVICE, 'directory');
    if (!dirHealthy) throw new Error('Directory service not healthy');

    // Create frontend service linked to directory
    try {
      dokku(`sso:frontend:create ${FRONTEND_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) throw e;
    }

    try {
      dokku(`sso:frontend:use-directory ${FRONTEND_SERVICE} ${DIR_SERVICE}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already linked')) {
        console.log('use-directory result:', e.message);
      }
    }

    dokku(`sso:frontend:config ${FRONTEND_SERVICE} DOMAIN=protect-test.local`);

    try {
      dokku(`sso:frontend:apply ${FRONTEND_SERVICE}`);
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
      try { dokku(`sso:frontend:unprotect ${FRONTEND_SERVICE} ${app}`, { quiet: true }); } catch {}
      try { dokku(`apps:destroy ${app} --force`, { quiet: true }); } catch {}
    }
    try { dokku(`sso:frontend:destroy ${FRONTEND_SERVICE} -f`, { quiet: true }); } catch {}
    try { dokku(`sso:destroy ${DIR_SERVICE} -f`, { quiet: true }); } catch {}
  });

  // --- sso:frontend:protect / sso:frontend:unprotect (explicit service) ---

  test('sso:frontend:protect should protect an app', async () => {
    const output = dokku(`sso:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('Protecting');
    expect(output).toContain('now protected');
  });

  test('sso:frontend:protect should be idempotent (re-applies without error)', async () => {
    const output = dokku(`sso:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('Protecting');
    expect(output).toContain('now protected');
  });

  test('sso:frontend:info should show protected app', async () => {
    const info = dokku(`sso:frontend:info ${FRONTEND_SERVICE}`);
    expect(info).toContain(TEST_APP);
  });

  test('sso:frontend:unprotect should remove protection', async () => {
    const output = dokku(`sso:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('Removing protection');
    expect(output).toContain('removed');
  });

  test('sso:frontend:unprotect on non-protected app should be no-op', async () => {
    const output = dokku(`sso:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`);
    expect(output).toContain('not protected');
  });

  // --- sso:protect / sso:unprotect (auto-detect) ---

  test('sso:protect should auto-detect single frontend', async () => {
    const output = dokku(`sso:protect ${TEST_APP}`);
    expect(output).toContain('Protecting');
    expect(output).toContain(FRONTEND_SERVICE);
    expect(output).toContain('now protected');
  });

  test('sso:protect should be idempotent (re-applies without error)', async () => {
    const output = dokku(`sso:protect ${TEST_APP}`);
    expect(output).toContain('Protecting');
    expect(output).toContain('now protected');
  });

  test('sso:unprotect should auto-detect protecting frontend', async () => {
    const output = dokku(`sso:unprotect ${TEST_APP}`);
    expect(output).toContain('Removing protection');
    expect(output).toContain(FRONTEND_SERVICE);
    expect(output).toContain('removed');
  });

  test('sso:unprotect on non-protected app should be no-op', async () => {
    const output = dokku(`sso:unprotect ${TEST_APP}`);
    expect(output).toContain('not protected');
  });

  // --- Protect multiple apps ---

  test('should protect multiple apps on same frontend', async () => {
    dokku(`sso:protect ${TEST_APP}`);
    dokku(`sso:protect ${TEST_APP_2}`);

    const info = dokku(`sso:frontend:info ${FRONTEND_SERVICE}`);
    expect(info).toContain(TEST_APP);
    expect(info).toContain(TEST_APP_2);

    // Cleanup
    dokku(`sso:unprotect ${TEST_APP}`);
    dokku(`sso:unprotect ${TEST_APP_2}`);
  });

  // --- sso:frontend:refresh ---

  test('sso:frontend:refresh should re-apply protection to all linked apps', async () => {
    // Protect both apps
    dokku(`sso:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);
    dokku(`sso:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP_2}`);

    // Refresh should re-apply both
    const output = dokku(`sso:frontend:refresh ${FRONTEND_SERVICE}`);
    expect(output).toContain('Refreshing SSO protection');
    expect(output).toContain(TEST_APP);
    expect(output).toContain(TEST_APP_2);
    expect(output).toContain('All apps refreshed');

    // Cleanup
    dokku(`sso:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`);
    dokku(`sso:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP_2}`);
  });

  test('sso:frontend:refresh with no protected apps should be no-op', async () => {
    const output = dokku(`sso:frontend:refresh ${FRONTEND_SERVICE}`);
    expect(output).toContain('No protected apps');
  });

  test('sso:frontend:refresh should skip destroyed apps', async () => {
    // Protect an app then destroy it
    dokku(`sso:frontend:protect ${FRONTEND_SERVICE} ${TEST_APP}`);
    dokku(`apps:destroy ${TEST_APP} --force`);

    // Refresh should skip the destroyed app
    const output = dokku(`sso:frontend:refresh ${FRONTEND_SERVICE}`);
    expect(output).toContain('Skipping');
    expect(output).toContain('no longer exists');

    // Recreate the app for other tests
    dokku(`apps:create ${TEST_APP}`);

    // Cleanup
    dokku(`sso:frontend:unprotect ${FRONTEND_SERVICE} ${TEST_APP}`);
  });

  test('sso:frontend:refresh should fail for non-existent service', async () => {
    try {
      dokku(`sso:frontend:refresh no-such-service`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  // --- Error cases ---

  test('sso:protect should fail for non-existent app', async () => {
    try {
      dokku(`sso:protect no-such-app-xyz`, { quiet: true });
      expect(true).toBe(false); // should not reach
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('sso:frontend:protect should fail for non-existent frontend', async () => {
    try {
      dokku(`sso:frontend:protect no-such-frontend ${TEST_APP}`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });

  test('sso:frontend:protect should fail for non-existent app', async () => {
    try {
      dokku(`sso:frontend:protect ${FRONTEND_SERVICE} no-such-app-xyz`, { quiet: true });
      expect(true).toBe(false);
    } catch (e: any) {
      expect(e.stderr).toContain('does not exist');
    }
  });
});
