import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { execSync } from 'child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, statSync, rmSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

const PLUGIN_DIR = join(__dirname, '../..');
const LOADER_PATH = join(PLUGIN_DIR, 'providers/loader.sh');

/**
 * Run safe_write by sourcing loader.sh in a bash subshell.
 */
function runSafeWrite(
  file: string,
  content: string,
  mode?: string
): { exitCode: number; stdout: string; stderr: string } {
  const modeArg = mode ? ` "${mode}"` : '';
  const cmd = `bash -c 'source "${LOADER_PATH}" && safe_write "${file}" "${content}"${modeArg}'`;
  try {
    const stdout = execSync(cmd, { encoding: 'utf-8', timeout: 10000 });
    return { exitCode: 0, stdout, stderr: '' };
  } catch (e: any) {
    return {
      exitCode: e.status ?? 1,
      stdout: e.stdout ?? '',
      stderr: e.stderr ?? '',
    };
  }
}

describe('safe_write', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'safe-write-test-'));
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('should create a new file with content', () => {
    const file = join(tmpDir, 'test-file');
    const result = runSafeWrite(file, 'hello world');
    expect(result.exitCode).toBe(0);
    expect(readFileSync(file, 'utf-8')).toBe('hello world\n');
  });

  it('should overwrite an existing file', () => {
    const file = join(tmpDir, 'test-file');
    writeFileSync(file, 'old content');
    const result = runSafeWrite(file, 'new content');
    expect(result.exitCode).toBe(0);
    expect(readFileSync(file, 'utf-8')).toBe('new content\n');
  });

  it('should set default mode 0600', () => {
    const file = join(tmpDir, 'test-file');
    runSafeWrite(file, 'secret');
    const mode = statSync(file).mode & 0o777;
    expect(mode).toBe(0o600);
  });

  it('should set custom mode when specified', () => {
    const file = join(tmpDir, 'test-file');
    runSafeWrite(file, 'public', '0644');
    const mode = statSync(file).mode & 0o777;
    expect(mode).toBe(0o644);
  });

  it('should not leave temp files on success', () => {
    const file = join(tmpDir, 'test-file');
    runSafeWrite(file, 'content');
    const files = execSync(`ls "${tmpDir}"`, { encoding: 'utf-8' }).trim().split('\n');
    expect(files).toEqual(['test-file']);
  });

  it('should overwrite a read-only file (via directory permission)', () => {
    const file = join(tmpDir, 'readonly-file');
    writeFileSync(file, 'old');
    execSync(`chmod 444 "${file}"`);
    const result = runSafeWrite(file, 'new');
    expect(result.exitCode).toBe(0);
    expect(readFileSync(file, 'utf-8')).toBe('new\n');
  });
});
