#!/usr/bin/env node
/**
 * Claude Code — Statusline
 *
 * Layout: [task] │ model │ repo │ uncommitted │ context bar % [compact hint] │ rate limit │ duration
 * ANSI colors only, so it paints with Ghostty's palette (Modest Dark); icons from the Nerd Font.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const AUTO_COMPACT_BUFFER_PCT = 16.5;
const COMPACT_SUGGEST_PCT = 55;

let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 3000);

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input);
    process.stdout.write(buildStatusline(data));
  } catch {
    // Silent fail
  }
});

function buildStatusline(data) {
  const parts = [];

  // 1. Current task (from todos)
  const task = getCurrentTask(data.session_id);
  if (task) {
    parts.push(`\x1b[1m\uf0ae ${task}\x1b[0m`);
  }

  // 2. Model
  const model = data.model?.display_name || 'Claude';
  parts.push(`\x1b[2m\u{f06a9} ${model}\x1b[0m`);

  // 3. Repo name
  const dir = data.workspace?.current_dir || process.cwd();
  parts.push(`\x1b[36m\uf401 ${path.basename(dir)}\x1b[0m`);

  // 4. Uncommitted files count
  const dirty = getUncommittedCount(dir);
  if (dirty !== null) parts.push(dirty);

  // 5. Context bar + compact suggestion
  const ctx = buildContextBar(data.context_window?.remaining_percentage);
  if (ctx) parts.push(ctx);

  // 6. Rate limit (5h)
  const rateLimit = buildRateLimit(data.rate_limits?.five_hour);
  if (rateLimit) parts.push(rateLimit);

  // 7. Session duration
  const duration = getSessionDuration(data.session_id, dir);
  if (duration) parts.push(`\x1b[2m\uf017 ${duration}\x1b[0m`);

  return parts.join(' \x1b[2m│\x1b[0m ');
}

function buildContextBar(remaining) {
  if (remaining == null) return '';

  const usableRemaining = Math.max(0, ((remaining - AUTO_COMPACT_BUFFER_PCT) / (100 - AUTO_COMPACT_BUFFER_PCT)) * 100);
  const used = Math.max(0, Math.min(100, Math.round(100 - usableRemaining)));

  const filled = Math.floor(used / 10);
  const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);

  // green, yellow, red, bold red
  const color = used < 50 ? '32' : used < 65 ? '33' : used < 80 ? '31' : '1;31';
  let colored = `\x1b[${color}m${bar} ${used}%\x1b[0m`;

  if (used >= COMPACT_SUGGEST_PCT) {
    colored += ` \x1b[33m/compact\x1b[0m`;
  }

  return colored;
}

function buildRateLimit(fiveHour) {
  if (!fiveHour || fiveHour.used_percentage == null) return null;
  const used = Math.round(fiveHour.used_percentage);
  if (used < 30) return null;

  let timeLeft = '';
  if (fiveHour.resets_at) {
    const remainingMs = fiveHour.resets_at * 1000 - Date.now();
    if (remainingMs > 0) {
      const mins = Math.floor(remainingMs / 60000);
      if (mins < 60) {
        timeLeft = `${mins}m`;
      } else {
        const hrs = Math.floor(mins / 60);
        const remMins = mins % 60;
        timeLeft = remMins > 0 ? `${hrs}h${remMins}m` : `${hrs}h`;
      }
    } else {
      timeLeft = '<1m';
    }
  }

  const label = `\uf252 ${timeLeft ? `${timeLeft}:${used}%` : `5h:${used}%`}`;
  if (used < 60) return `\x1b[2m${label}\x1b[0m`;
  if (used < 80) return `\x1b[33m${label}\x1b[0m`;
  return `\x1b[31m${label}\x1b[0m`;
}

function getUncommittedCount(dir) {
  try {
    const out = execSync('git status --porcelain', {
      cwd: dir,
      timeout: 2000,
      stdio: ['pipe', 'pipe', 'pipe'],
      encoding: 'utf8'
    });
    const count = out.split('\n').filter(Boolean).length;
    if (count === 0) return null;
    const color = count >= 10 ? '31' : count >= 5 ? '33' : '2';
    return `\x1b[${color}m\uf044 ${count} files\x1b[0m`;
  } catch {
    return null;
  }
}

function getCurrentTask(sessionId) {
  if (!sessionId) return null;

  const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
  const todosDir = path.join(claudeDir, 'todos');

  if (!fs.existsSync(todosDir)) return null;

  try {
    const files = fs.readdirSync(todosDir)
      .filter(f => f.startsWith(sessionId) && f.includes('-agent-') && f.endsWith('.json'))
      .map(f => {
        try {
          return { name: f, mtime: fs.statSync(path.join(todosDir, f)).mtime };
        } catch { return null; }
      })
      .filter(Boolean)
      .sort((a, b) => b.mtime - a.mtime);

    if (files.length === 0) return null;

    const todos = JSON.parse(fs.readFileSync(path.join(todosDir, files[0].name), 'utf8'));
    const inProgress = todos.find(t => t.status === 'in_progress');
    if (inProgress) {
      const text = inProgress.activeForm || inProgress.content || '';
      return text.length > 30 ? text.slice(0, 28) + '..' : text;
    }
  } catch { /* silent */ }

  return null;
}

function getSessionDuration(sessionId, dir) {
  const sessionsDir = path.join(
    process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude'),
    'sessions'
  );

  if (!fs.existsSync(sessionsDir)) return null;

  try {
    const today = new Date().toISOString().slice(0, 10);
    const project = path.basename(dir || process.cwd());
    const target = `${today}-${project}-session.tmp`;

    const filePath = path.join(sessionsDir, target);
    if (!fs.existsSync(filePath)) return null;

    const stats = fs.statSync(filePath);
    const elapsed = Date.now() - stats.birthtimeMs;
    const mins = Math.floor(elapsed / 60000);

    if (mins < 1) return '<1m';
    if (mins < 60) return `${mins}m`;
    const hrs = Math.floor(mins / 60);
    const remMins = mins % 60;
    return `${hrs}h${remMins > 0 ? remMins + 'm' : ''}`;
  } catch { /* silent */ }

  return null;
}
