import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';

/**
 * Gitea LDAP Login E2E Test
 *
 * Tests the full flow of:
 * 1. Creating an LLDAP directory service
 * 2. Deploying Gitea as a dokku app
 * 3. Configuring Gitea to use LDAP authentication
 * 4. Creating a test user in LLDAP
 * 5. Logging into Gitea with LDAP credentials
 */

const SERVICE_NAME = 'gitea-ldap-test';
const GITEA_APP = 'gitea-test';
const TEST_USER = 'testuser';
const TEST_PASSWORD = 'TestPass123!';
const TEST_EMAIL = 'testuser@test.local';
const USE_SUDO = process.env.DOKKU_USE_SUDO === 'true';

// Helper to run dokku commands
function dokku(cmd: string): string {
  const dokkuCmd = USE_SUDO ? `sudo dokku ${cmd}` : `dokku ${cmd}`;
  console.log(`$ ${dokkuCmd}`);
  try {
    const result = execSync(dokkuCmd, { encoding: 'utf8', timeout: 300000 });
    console.log(result);
    return result;
  } catch (error: any) {
    console.error(`Failed:`, error.stderr || error.message);
    throw error;
  }
}

// Helper to run shell commands
function sh(cmd: string): string {
  console.log(`$ ${cmd}`);
  try {
    const result = execSync(cmd, { encoding: 'utf8', timeout: 300000 });
    return result;
  } catch (error: any) {
    console.error(`Failed:`, error.stderr || error.message);
    throw error;
  }
}

// Get container IP
function getContainerIp(containerName: string): string {
  return execSync(
    `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${containerName}`,
    { encoding: 'utf-8' }
  ).trim();
}

// Get LLDAP credentials
function getLdapCredentials(): Record<string, string> {
  const output = dokku(`auth:credentials ${SERVICE_NAME}`);
  const creds: Record<string, string> = {};
  for (const line of output.split('\n')) {
    const match = line.match(/^(\w+)=(.+)$/);
    if (match) {
      creds[match[1]] = match[2];
    }
  }
  return creds;
}

// Create user in LLDAP via GraphQL API
async function createLdapUser(
  lldapUrl: string,
  adminPassword: string,
  userId: string,
  email: string,
  password: string
): Promise<void> {
  // Get auth token
  const loginResponse = await fetch(`${lldapUrl}/auth/simple/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: adminPassword }),
  });

  if (!loginResponse.ok) {
    throw new Error(`Failed to login to LLDAP: ${await loginResponse.text()}`);
  }

  const { token } = await loginResponse.json();

  // Create user
  const createUserQuery = `
    mutation CreateUser($user: CreateUserInput!) {
      createUser(user: $user) {
        id
        email
      }
    }
  `;

  const createResponse = await fetch(`${lldapUrl}/api/graphql`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({
      query: createUserQuery,
      variables: {
        user: {
          id: userId,
          email: email,
        },
      },
    }),
  });

  const createResult = await createResponse.json();
  if (createResult.errors) {
    // Ignore "already exists" errors
    if (!createResult.errors[0]?.message?.includes('already exists')) {
      console.log('Create user result:', JSON.stringify(createResult, null, 2));
    }
  }

  // Set user password
  const setPasswordQuery = `
    mutation SetPassword($userId: String!, $password: String!) {
      setPassword(userId: $userId, password: $password) {
        ok
      }
    }
  `;

  await fetch(`${lldapUrl}/api/graphql`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({
      query: setPasswordQuery,
      variables: {
        userId: userId,
        password: password,
      },
    }),
  });

  // Add user to default group so they can access apps
  const addToGroupQuery = `
    mutation AddUserToGroup($userId: String!, $groupId: Int!) {
      addUserToGroup(userId: $userId, groupId: $groupId) {
        ok
      }
    }
  `;

  // Get the app's user group ID (created by auth:link)
  const groupsResponse = await fetch(`${lldapUrl}/api/graphql`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({
      query: '{ groups { id displayName } }',
    }),
  });

  const groupsResult = await groupsResponse.json();
  const appGroup = groupsResult.data?.groups?.find(
    (g: any) => g.displayName === `${GITEA_APP}_users`
  );

  if (appGroup) {
    await fetch(`${lldapUrl}/api/graphql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({
        query: addToGroupQuery,
        variables: {
          userId: userId,
          groupId: appGroup.id,
        },
      }),
    });
  }

  console.log(`Created LDAP user: ${userId}`);
}

let LLDAP_URL: string;
let GITEA_URL: string;
let LDAP_CONTAINER_IP: string;

test.describe('Gitea LDAP Login', () => {
  test.beforeAll(async () => {
    console.log('=== Setting up Gitea LDAP test environment ===');

    // 1. Create LLDAP directory service
    console.log('Creating LLDAP directory service...');
    try {
      dokku(`auth:create ${SERVICE_NAME}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) {
        throw e;
      }
    }

    // Wait for LLDAP to be healthy
    let healthy = false;
    for (let i = 0; i < 30; i++) {
      try {
        const statusCmd = USE_SUDO
          ? `sudo dokku auth:status ${SERVICE_NAME}`
          : `dokku auth:status ${SERVICE_NAME}`;
        const status = execSync(statusCmd, { encoding: 'utf-8' });
        if (status.includes('healthy')) {
          healthy = true;
          break;
        }
      } catch {}
      await new Promise((r) => setTimeout(r, 2000));
    }
    if (!healthy) {
      throw new Error('LLDAP service not healthy');
    }

    LDAP_CONTAINER_IP = getContainerIp(`dokku.auth.directory.${SERVICE_NAME}`);
    LLDAP_URL = `http://${LDAP_CONTAINER_IP}:17170`;
    console.log(`LLDAP URL: ${LLDAP_URL}`);

    // 2. Create Gitea app
    console.log('Creating Gitea app...');
    try {
      dokku(`apps:create ${GITEA_APP}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) {
        throw e;
      }
    }

    // 3. Link Gitea to LLDAP (sets LDAP env vars)
    console.log('Linking Gitea to LLDAP...');
    try {
      dokku(`auth:link ${SERVICE_NAME} ${GITEA_APP}`);
    } catch (e: any) {
      if (!e.stderr?.includes('already linked')) {
        throw e;
      }
    }

    // 4. Configure and deploy Gitea
    console.log('Configuring Gitea...');
    const creds = getLdapCredentials();

    // Set Gitea configuration
    dokku(`config:set --no-restart ${GITEA_APP} ` +
      `GITEA__database__DB_TYPE=sqlite3 ` +
      `GITEA__database__PATH=/data/gitea/gitea.db ` +
      `GITEA__security__INSTALL_LOCK=true ` +
      `GITEA__security__SECRET_KEY=supersecretkey123456789012345678 ` +
      `GITEA__server__DOMAIN=${GITEA_APP}.local ` +
      `GITEA__server__ROOT_URL=http://${GITEA_APP}.local/ ` +
      `GITEA__service__DISABLE_REGISTRATION=true`
    );

    // Set storage
    dokku(`storage:ensure-directory ${GITEA_APP}`);
    try {
      dokku(`storage:mount ${GITEA_APP} /var/lib/dokku/data/storage/${GITEA_APP}:/data`);
    } catch (e: any) {
      if (!e.stderr?.includes('already exists')) {
        throw e;
      }
    }

    // Deploy Gitea from Docker Hub
    console.log('Deploying Gitea...');
    sh(`docker pull gitea/gitea:latest`);
    dokku(`git:from-image ${GITEA_APP} gitea/gitea:latest`);

    // Wait for Gitea to start
    console.log('Waiting for Gitea to start...');
    await new Promise((r) => setTimeout(r, 10000));

    // Get Gitea URL
    const giteaContainerName = `${GITEA_APP}.web.1`;
    let giteaIp: string;
    try {
      giteaIp = getContainerIp(giteaContainerName);
    } catch {
      // Try alternate container name format
      giteaIp = getContainerIp(`dokku.${GITEA_APP}.web.1`);
    }
    GITEA_URL = `http://${giteaIp}:3000`;
    console.log(`Gitea URL: ${GITEA_URL}`);

    // 5. Configure LDAP authentication in Gitea via API
    console.log('Configuring LDAP authentication in Gitea...');

    // First, create an admin user via environment
    // Gitea requires initial admin setup, we'll do it via the UI or skip if exists

    // 6. Create test user in LLDAP
    console.log('Creating test user in LLDAP...');
    await createLdapUser(
      LLDAP_URL,
      creds.ADMIN_PASSWORD,
      TEST_USER,
      TEST_EMAIL,
      TEST_PASSWORD
    );

    console.log('=== Setup complete ===');
  }, 600000); // 10 minute timeout for setup

  test.afterAll(async () => {
    console.log('=== Cleaning up Gitea LDAP test environment ===');
    try {
      dokku(`apps:destroy ${GITEA_APP} --force`);
    } catch (e) {
      console.log('Failed to destroy Gitea app:', e);
    }
    try {
      dokku(`auth:destroy ${SERVICE_NAME} -f`);
    } catch (e) {
      console.log('Failed to destroy LLDAP service:', e);
    }
  });

  test('Gitea should be running', async ({ page }) => {
    await page.goto(GITEA_URL, { timeout: 30000 });
    // Gitea shows either login page or install page
    await expect(
      page.locator('input[name="user_name"], input[name="db_type"], .login')
    ).toBeVisible({ timeout: 15000 });
  });

  test('should configure LDAP authentication source', async ({ page }) => {
    const creds = getLdapCredentials();

    // This test configures LDAP via Gitea's admin UI
    // First we need to complete initial setup if not done
    await page.goto(GITEA_URL);

    // Check if we need to do initial setup
    const needsSetup = await page.locator('input[name="db_type"]').isVisible().catch(() => false);

    if (needsSetup) {
      console.log('Completing Gitea initial setup...');
      // Fill in minimal setup - SQLite is already configured via env
      await page.locator('input[name="admin_name"]').fill('gitea_admin');
      await page.locator('input[name="admin_passwd"]').fill('AdminPass123!');
      await page.locator('input[name="admin_confirm_passwd"]').fill('AdminPass123!');
      await page.locator('input[name="admin_email"]').fill('admin@test.local');
      await page.locator('button[type="submit"]').click();
      await page.waitForTimeout(5000);
    }

    // Login as admin
    await page.goto(`${GITEA_URL}/user/login`);
    await page.locator('input[name="user_name"]').fill('gitea_admin');
    await page.locator('input[name="password"]').fill('AdminPass123!');
    await page.locator('button[type="submit"], input[type="submit"]').click();
    await page.waitForTimeout(2000);

    // Go to admin authentication sources
    await page.goto(`${GITEA_URL}/admin/auths/new`);

    // Configure LDAP
    await page.locator('select[name="type"]').selectOption('2'); // LDAP via BindDN
    await page.waitForTimeout(500);

    await page.locator('input[name="name"]').fill('LLDAP');
    await page.locator('input[name="host"]').fill(LDAP_CONTAINER_IP);
    await page.locator('input[name="port"]').fill('3890');
    await page.locator('input[name="bind_dn"]').fill(creds.BIND_DN);
    await page.locator('input[name="bind_password"]').fill(creds.ADMIN_PASSWORD);
    await page.locator('input[name="user_base"]').fill(`ou=people,${creds.BASE_DN}`);
    await page.locator('input[name="filter"]').fill('(&(objectClass=person)(uid=%s))');
    await page.locator('input[name="admin_filter"]').fill('');
    await page.locator('input[name="attribute_username"]').fill('uid');
    await page.locator('input[name="attribute_name"]').fill('cn');
    await page.locator('input[name="attribute_surname"]').fill('sn');
    await page.locator('input[name="attribute_mail"]').fill('mail');

    // Submit
    await page.locator('button[type="submit"]').click();
    await page.waitForTimeout(2000);

    // Verify it was created
    await page.goto(`${GITEA_URL}/admin/auths`);
    await expect(page.locator('text=LLDAP')).toBeVisible();
  });

  test('should login to Gitea with LDAP credentials', async ({ page }) => {
    // Logout first if logged in
    await page.goto(`${GITEA_URL}/user/logout`);
    await page.waitForTimeout(1000);

    // Go to login page
    await page.goto(`${GITEA_URL}/user/login`);

    // Login with LDAP user
    await page.locator('input[name="user_name"]').fill(TEST_USER);
    await page.locator('input[name="password"]').fill(TEST_PASSWORD);
    await page.locator('button[type="submit"], input[type="submit"]').click();

    // Should be logged in - look for user menu or dashboard
    await expect(
      page.locator('.user-dropdown, .dashboard, [aria-label="Profile"], .avatar').first()
    ).toBeVisible({ timeout: 15000 });

    // Verify username is shown
    await expect(page.locator(`text=${TEST_USER}`).first()).toBeVisible({ timeout: 5000 });
  });

  test('should show user profile with LDAP attributes', async ({ page }) => {
    // Login first
    await page.goto(`${GITEA_URL}/user/login`);
    await page.locator('input[name="user_name"]').fill(TEST_USER);
    await page.locator('input[name="password"]').fill(TEST_PASSWORD);
    await page.locator('button[type="submit"], input[type="submit"]').click();
    await page.waitForTimeout(2000);

    // Go to profile settings
    await page.goto(`${GITEA_URL}/user/settings`);

    // Check email matches LDAP
    const emailInput = page.locator('input[name="email"]');
    await expect(emailInput).toHaveValue(TEST_EMAIL);
  });
});
