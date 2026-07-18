#!/usr/bin/env node
import { cp, lstat, mkdir, readdir, rename, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { homedir, platform } from 'node:os';
import { basename, dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const diagnosticNames = new Set([
  'codex-version', 'system-resources', 'codex-process-cpu-memory', 'codex-process-io',
  'codex-gpu', 'codex-child-processes', 'wsl-environment', 'display-drivers',
  'state-database-integrity', 'log-database-integrity', 'log-wal-growth',
  'log-level-summary', 'thread-state-summary', 'large-rollout-files',
  'abnormal-thread-metadata', 'temporary-files', 'workspace-state', 'codex-configuration',
]);
const remediationNames = new Set([
  'backup-codex-databases', 'backup-codex-state', 'archive-thread-consistently',
  'quarantine-rollout-file', 'quarantine-stale-temp-files', 'remove-stale-workspace-state',
  'remove-wsl-environment-marker', 'block-log-inserts', 'restore-log-inserts', 'restore-codex-backup',
]);
const args = process.argv.slice(2);
const [mode, name] = args;
const value = (flag, fallback = '') => args.includes(flag) ? args[args.indexOf(flag) + 1] : fallback;
const has = (flag) => args.includes(flag);
const home = resolve(value('--codex-home', process.env.CODEX_HOME || join(homedir(), '.codex')));
const now = () => new Date().toISOString().replace(/[:.]/g, '-');
const result = (check, status, data = {}, notes = []) => console.log(JSON.stringify({ check, status, data, notes }));
const withinHome = (path) => resolve(path).startsWith(`${home}/`) || resolve(path) === home;

async function size(path) { try { return (await stat(path)).size; } catch { return 0; } }
async function files(root, suffix = '') {
  if (!existsSync(root)) return [];
  const output = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) output.push(...await files(path, suffix));
    else if (!suffix || entry.name.endsWith(suffix)) output.push(path);
  }
  return output;
}
function ps() {
  if (platform() === 'win32') return [];
  try { return execFileSync('ps', ['-ax', '-o', 'pid=,ppid=,%cpu=,rss=,command='], { encoding: 'utf8' }).split('\n').filter(Boolean); } catch { return []; }
}
function codexProcesses() { return ps().filter((row) => /Codex \(|\/codex(?: |$)|com\.openai\.codex/i.test(row)); }
async function sqlite(path, callback) {
  if (!existsSync(path)) return null;
  const { DatabaseSync } = await import('node:sqlite');
  const db = new DatabaseSync(`file:${path}?mode=ro`);
  try { return callback(db); } finally { db.close(); }
}

async function diagnose(check) {
  if (!diagnosticNames.has(check)) throw new Error(`unknown diagnostic: ${check}`);
  const state = join(home, 'state_5.sqlite');
  const logs = join(home, 'logs_2.sqlite');
  const sessions = join(home, 'sessions');
  if (check === 'codex-version') return result(check, 'ok', { platform: platform(), node: process.version, codex_home: home });
  if (check === 'system-resources') {
    const disk = platform() === 'win32' ? '' : execFileSync('df', ['-k', home], { encoding: 'utf8' }).trim().split('\n').at(-1);
    return result(check, 'ok', { cpus: (await import('node:os')).cpus().length, free_memory_bytes: (await import('node:os')).freemem(), disk });
  }
  if (check === 'codex-process-cpu-memory') return result(check, codexProcesses().length ? 'ok' : 'skipped', { processes: codexProcesses() });
  if (check === 'codex-process-io') return result(check, 'skipped', {}, ['Per-process I/O counters are not exposed consistently by Node.js across platforms.']);
  if (check === 'codex-gpu') return result(check, 'skipped', {}, ['GPU engine counters are platform-specific.']);
  if (check === 'codex-child-processes') return result(check, 'ok', { processes: codexProcesses().filter((row) => /git|wsl|bash|powershell|pwsh|python/i.test(row)) });
  if (check === 'wsl-environment') return result(check, platform() === 'win32' ? (process.env.WSL_DISTRO_NAME ? 'warning' : 'ok') : 'skipped', { WSL_DISTRO_NAME: process.env.WSL_DISTRO_NAME || null });
  if (check === 'display-drivers') return result(check, 'skipped', {}, ['Display-driver inspection is not portable.']);
  if (check === 'state-database-integrity' || check === 'log-database-integrity') {
    const path = check.startsWith('state') ? state : logs;
    const data = await sqlite(path, (db) => ({ integrity: db.prepare('PRAGMA integrity_check').all(), tables: db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all() }));
    return result(check, data ? (data.integrity.length === 1 && data.integrity[0].integrity_check === 'ok' ? 'ok' : 'error') : 'skipped', data || { path });
  }
  if (check === 'log-wal-growth') {
    const wal = `${logs}-wal`; const before = await size(wal); await new Promise((r) => setTimeout(r, Number(value('--sample-seconds', '15')) * 1000)); const after = await size(wal);
    return result(check, after > before ? 'warning' : 'ok', { wal, before_bytes: before, after_bytes: after, growth_bytes: after - before });
  }
  if (check === 'log-level-summary') return result(check, existsSync(logs) ? 'skipped' : 'skipped', { path: logs }, ['Log schema varies by release; inspect only after a supported schema is confirmed.']);
  if (check === 'thread-state-summary') {
    const data = await sqlite(state, (db) => ({ tables: db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all() }));
    const taskFiles = await files(sessions, '.jsonl'); const total = (await Promise.all(taskFiles.map(size))).reduce((a, b) => a + b, 0);
    return result(check, existsSync(state) || taskFiles.length ? (taskFiles.length > 500 ? 'warning' : 'ok') : 'skipped', { state_database: data, session_files: taskFiles.length, session_bytes: total });
  }
  if (check === 'large-rollout-files') { const rows = (await files(sessions, '.jsonl')).map(async (path) => ({ path, bytes: await size(path) })); const data = (await Promise.all(rows)).filter((row) => row.bytes >= 8 * 1024 * 1024); return result(check, data.length ? 'warning' : 'ok', { candidates: data }); }
  if (check === 'abnormal-thread-metadata') return result(check, 'skipped', {}, ['Thread metadata requires a supported state database schema.']);
  if (check === 'temporary-files') { const roots = ['.tmp', 'tmp'].map((x) => join(home, x)); const rows = (await Promise.all(roots.map((root) => files(root)))).flat(); return result(check, rows.length > 1000 ? 'warning' : 'ok', { roots, file_count: rows.length }); }
  if (check === 'workspace-state') { const path = join(home, '.codex-global-state.json'); return result(check, existsSync(path) ? 'ok' : 'skipped', { path, bytes: await size(path) }); }
  if (check === 'codex-configuration') { const path = join(home, 'config.toml'); return result(check, existsSync(path) ? 'ok' : 'skipped', { path, bytes: await size(path) }); }
}

async function ensureStopped() { if (codexProcesses().length) throw new Error('Quit Codex before applying a remediation.'); }
async function backup(paths, label) {
  const target = join(home, 'performance-backups', `${label}-${now()}`); await mkdir(target, { recursive: true });
  for (const path of paths) if (existsSync(path)) await cp(path, join(target, basename(path)));
  return target;
}
async function writeDb(path, callback) {
  const { DatabaseSync } = await import('node:sqlite');
  const db = new DatabaseSync(path);
  try { return callback(db); } finally { db.close(); }
}
async function quarantineTemp() {
  const cutoff = Date.now() - Number(value('--older-than-days', '7')) * 86400000;
  const roots = ['.tmp', 'tmp'].map((x) => join(home, x));
  const candidates = (await Promise.all(roots.map((root) => files(root)))).flat();
  const stale = [];
  for (const path of candidates) if ((await lstat(path)).mtimeMs < cutoff) stale.push(path);
  const targetRoot = join(home, 'performance-quarantine', 'temp', now());
  for (const source of stale) { const target = join(targetRoot, relative(home, source)); await mkdir(dirname(target), { recursive: true }); await rename(source, target); }
  return { candidates: stale.length, target: targetRoot };
}
async function removeWorkspace() {
  const workspace = resolve(value('--workspace-path'));
  const state = join(home, '.codex-global-state.json');
  const backupPath = await backup([state], 'workspace-state');
  const data = JSON.parse(await (await import('node:fs/promises')).readFile(state, 'utf8'));
  const equals = (item) => typeof item === 'string' && resolve(item) === workspace;
  const keys = ['electron-saved-workspace-roots', 'active-workspace-roots', 'project-order', 'pinned-project-ids'];
  const changed = [];
  for (const key of keys) if (Array.isArray(data[key])) { const next = data[key].filter((item) => !equals(item)); if (next.length !== data[key].length) { data[key] = next; changed.push(key); } }
  if (data['electron-workspace-root-labels'] && typeof data['electron-workspace-root-labels'] === 'object') for (const key of Object.keys(data['electron-workspace-root-labels'])) if (resolve(key) === workspace) { delete data['electron-workspace-root-labels'][key]; changed.push('electron-workspace-root-labels'); }
  await (await import('node:fs/promises')).writeFile(state, JSON.stringify(data));
  return { changed, backup: backupPath };
}
async function remediate(action) {
  if (!remediationNames.has(action)) throw new Error(`unknown remediation: ${action}`);
  if (has('--what-if') === has('--apply')) throw new Error('Specify exactly one of --what-if or --apply.');
  const applied = has('--apply'); const preview = { action, applied: false, codex_home: home };
  if (!applied) return console.log(JSON.stringify(preview));
  await ensureStopped();
  if (action === 'backup-codex-databases') return console.log(JSON.stringify({ action, applied: true, backup: await backup([join(home, 'state_5.sqlite'), join(home, 'logs_2.sqlite')], 'databases') }));
  if (action === 'backup-codex-state') return console.log(JSON.stringify({ action, applied: true, backup: await backup([join(home, 'config.toml'), join(home, '.codex-global-state.json'), join(home, 'session_index.jsonl')], 'state') }));
  if (action === 'quarantine-rollout-file') {
    const source = resolve(value('--rollout-path')); if (!withinHome(source) || !/\/(sessions|archived_sessions)\//.test(source)) throw new Error('Rollout path must be under Codex session roots.');
    const target = join(home, 'performance-quarantine', 'rollouts', now(), basename(source)); await mkdir(dirname(target), { recursive: true }); await rename(source, target); return console.log(JSON.stringify({ action, applied: true, source, target }));
  }
  if (action === 'quarantine-stale-temp-files') return console.log(JSON.stringify({ action, applied: true, result: await quarantineTemp() }));
  if (action === 'remove-stale-workspace-state') return console.log(JSON.stringify({ action, applied: true, result: await removeWorkspace() }));
  if (action === 'block-log-inserts' || action === 'restore-log-inserts') {
    const dbPath = join(home, 'logs_2.sqlite'); const trigger = value('--trigger-name', 'block_log_inserts');
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(trigger)) throw new Error('Invalid trigger name.');
    const backupPath = await backup([dbPath], `log-trigger-${action}`);
    const changed = await writeDb(dbPath, (db) => {
      const row = db.prepare("SELECT name FROM sqlite_master WHERE type='trigger' AND name=?").get(trigger);
      if (action === 'block-log-inserts' && !row) db.exec(`CREATE TRIGGER "${trigger}" BEFORE INSERT ON logs BEGIN SELECT RAISE(IGNORE); END`);
      if (action === 'restore-log-inserts' && row) db.exec(`DROP TRIGGER "${trigger}"`);
      return action === 'block-log-inserts' ? !row : Boolean(row);
    });
    return console.log(JSON.stringify({ action, applied: true, changed, backup: backupPath }));
  }
  if (action === 'restore-codex-backup') {
    const source = resolve(value('--backup-directory'));
    if (!withinHome(source) || !source.startsWith(join(home, 'performance-backups'))) throw new Error('Backup directory must be under performance-backups.');
    const names = ['state_5.sqlite', 'logs_2.sqlite', 'config.toml', '.codex-global-state.json', 'session_index.jsonl'];
    const backupPath = await backup(names.map((name) => join(home, name)), 'pre-restore');
    for (const name of names) if (existsSync(join(source, name))) await cp(join(source, name), join(home, name));
    return console.log(JSON.stringify({ action, applied: true, source, pre_restore_backup: backupPath }));
  }
  if (action === 'archive-thread-consistently') {
    const id = value('--thread-id'); if (!/^[0-9a-fA-F-]{20,}$/.test(id)) throw new Error('Invalid thread id.');
    const dbPath = join(home, 'state_5.sqlite'); const backupPath = await backup([dbPath], 'thread-archive');
    const row = await writeDb(dbPath, (db) => { const found = db.prepare('SELECT rollout_path FROM threads WHERE id=?').get(id); if (!found) throw new Error('Thread not found.'); db.prepare('UPDATE threads SET archived=1, archived_at=? WHERE id=?').run(Date.now(), id); return found; });
    return console.log(JSON.stringify({ action, applied: true, thread_id: id, rollout_path: row.rollout_path, backup: backupPath }));
  }
  if (action === 'remove-wsl-environment-marker' && platform() !== 'win32') return console.log(JSON.stringify({ action, applied: false, status: 'skipped', notes: ['Windows-only remediation.'] }));
  if (action === 'remove-wsl-environment-marker') { execFileSync('reg', ['delete', 'HKCU\\Environment', '/v', 'WSL_DISTRO_NAME', '/f']); return console.log(JSON.stringify({ action, applied: true })); }
}

try {
  if (mode === 'diagnose') await diagnose(name);
  else if (mode === 'remediate') await remediate(name);
  else throw new Error('Usage: codex-performance.mjs diagnose <check> | remediate <action> --what-if|--apply [--codex-home PATH]');
} catch (error) { console.error(JSON.stringify({ status: 'error', message: error.message })); process.exitCode = 1; }
