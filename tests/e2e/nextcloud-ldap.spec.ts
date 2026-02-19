import { test, expect } from '@playwright/test';
import {
  dokku,
  cleanupApp,
  waitForAppHealthy,
  waitForHttp,
  addHostsEntry,
  setupAuthServices,
  teardownAuthServices,
  createLdapTestUser,
  loginViaAuthelia,
  verifyAutheliaRedirect,
  waitForAuthHealthy,
  pluginAvailable,
  type TestUser,
} from './helpers';

/**
 * Nextcloud LDAP Integration E2E Test
 *
 * Tests Nextcloud deployed via library:checkout with Authelia forward auth:
 * 1. Deploy Nextcloud as a proper dokku app (with PostgreSQL)
 * 2. Protect it with Authelia forward auth
 * 3. Verify auth redirect and login flow
 *
 * Note: library:checkout handles PostgreSQL setup and Nextcloud configuration.
 * Forward auth protects the app at the nginx level.
 */

const APP = 'test-nextcloud-ldap';
const DOMAIN = `${APP}.test.local`;
const AUTH_SERVICE = 'nextcloud-ldap-auth';
const FRONTEND_SERVICE = 'nextcloud-ldap-fe';
const TEST_USER: TestUser = {
  username: 'ncuser',
  email: 'ncuser@test.local',
  password: 'NcPass123!',
};

test.describe('Nextcloud LDAP Integration', () => {
  test.describe.configure({ mode: 'serial' });

  test.beforeAll(async () => {
    test.skip(!pluginAvailable('postgres'), 'postgres plugin not available');

    console.log('=== Setting up Nextcloud LDAP test ===');

    setupAuthServices(AUTH_SERVICE, FRONTEND_SERVICE);
    await waitForAuthHealthy(AUTH_SERVICE);
    createLdapTestUser(AUTH_SERVICE, TEST_USER);
    addHostsEntry(DOMAIN);

    dokku(
      `library:checkout nextcloud --name=${APP} --domain=${DOMAIN} --no-ssl --non-interactive --auth-service=${AUTH_SERVICE}`,
      { timeout: 300000 },
    );

    console.log('=== Setup complete ===');
  }, 600000);

  test.afterAll(() => {
    cleanupApp(APP);
    teardownAuthServices(AUTH_SERVICE, FRONTEND_SERVICE);
  });

  test('app is running and responds on HTTP', async () => {
    const healthy = await waitForAppHealthy(APP, 180000);
    expect(healthy).toBe(true);
    const httpReady = await waitForHttp(`http://${DOMAIN}/`, 60000);
    expect(httpReady).toBe(true);
  });

  test('unauthenticated access redirects to Authelia', async ({ page }) => {
    await page.context().clearCookies();
    const redirected = await verifyAutheliaRedirect(page, `http://${DOMAIN}/`);
    expect(redirected).toBe(true);
  });

  test('login via Authelia grants access to Nextcloud', async ({ page }) => {
    await page.context().clearCookies();

    await page.goto(`http://${DOMAIN}/`);
    await loginViaAuthelia(page, TEST_USER.username, TEST_USER.password);

    await expect(page).toHaveURL(new RegExp(DOMAIN));

    // Nextcloud shows its login page or dashboard after forward auth
    const content = await page.content();
    expect(
      content.includes('Nextcloud') ||
      content.includes('nextcloud') ||
      content.includes('Files') ||
      content.includes('Dashboard'),
    ).toBe(true);
  });

  test('cleanup succeeds', () => {
    const output = dokku(`library:cleanup ${APP} --force`, {
      timeout: 120000,
      swallowErrors: true,
    });
    expect(output).toContain('cleaned up');
  });
});
