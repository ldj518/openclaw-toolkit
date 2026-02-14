#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const HOME = process.env.HOME || '/root';
const CONFIG = process.env.CONFIG || path.join(HOME, '.openclaw', 'openclaw.json');
const STATE = process.env.STATE || path.join(HOME, '.openclaw', 'watchdog-state', 'memory-guard.json');
const LOG = process.env.LOG || path.join(HOME, '.openclaw', 'memory-guard.log');

const LOW_MB = Number(process.env.LOW_MB || 350);      // 低于此值进入降载
const RECOVER_MB = Number(process.env.RECOVER_MB || 750); // 高于此值恢复

const PRIMARY_MODEL = process.env.PRIMARY_MODEL || 'openai-codex/gpt-5.3-codex';
const FALLBACK_MODEL = process.env.FALLBACK_MODEL || 'zai/glm-4.7';

function ts() { return new Date().toISOString(); }
function log(msg) {
  fs.mkdirSync(path.dirname(LOG), { recursive: true });
  fs.appendFileSync(LOG, `[${ts()}] ${msg}\n`);
  console.log(msg);
}

function readJson(p, d = {}) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return d; } }
function writeJson(p, o) { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, JSON.stringify(o, null, 2)); }

function memAvailableMB() {
  const txt = fs.readFileSync('/proc/meminfo', 'utf8');
  const m = txt.match(/^MemAvailable:\s+(\d+)\s+kB$/m);
  if (!m) return -1;
  return Math.floor(Number(m[1]) / 1024);
}

function restartGatewayBestEffort() {
  try { execSync('openclaw gateway restart >/dev/null 2>&1', { stdio: 'pipe' }); } catch {}
}

function applyDegraded(cfg, snapshot) {
  cfg.agents = cfg.agents || {};
  cfg.agents.defaults = cfg.agents.defaults || {};
  cfg.agents.defaults.model = cfg.agents.defaults.model || {};
  cfg.agents.defaults.subagents = cfg.agents.defaults.subagents || {};

  cfg.agents.defaults.maxConcurrent = 1;
  cfg.agents.defaults.subagents.maxConcurrent = 1;

  const currentPrimary = cfg.agents.defaults.model.primary || PRIMARY_MODEL;
  cfg.agents.defaults.model.primary = FALLBACK_MODEL;

  const fb = Array.isArray(cfg.agents.defaults.model.fallbacks) ? cfg.agents.defaults.model.fallbacks : [];
  const merged = [PRIMARY_MODEL, ...fb.filter(x => x !== PRIMARY_MODEL && x !== FALLBACK_MODEL)];
  cfg.agents.defaults.model.fallbacks = merged;

  snapshot.prevPrimary = currentPrimary;
}

function restoreNormal(cfg, snapshot) {
  cfg.agents = cfg.agents || {};
  cfg.agents.defaults = cfg.agents.defaults || {};
  cfg.agents.defaults.model = cfg.agents.defaults.model || {};
  cfg.agents.defaults.subagents = cfg.agents.defaults.subagents || {};

  cfg.agents.defaults.maxConcurrent = snapshot.prevMaxConcurrent ?? 4;
  cfg.agents.defaults.subagents.maxConcurrent = snapshot.prevSubMaxConcurrent ?? 8;

  cfg.agents.defaults.model.primary = snapshot.prevPrimary || PRIMARY_MODEL;

  const fb = Array.isArray(cfg.agents.defaults.model.fallbacks) ? cfg.agents.defaults.model.fallbacks : [];
  if (!fb.includes(FALLBACK_MODEL)) fb.unshift(FALLBACK_MODEL);
  cfg.agents.defaults.model.fallbacks = fb;
}

function main() {
  const avail = memAvailableMB();
  if (avail < 0) return;

  const state = readJson(STATE, {
    degraded: false,
    prevPrimary: PRIMARY_MODEL,
    prevMaxConcurrent: 4,
    prevSubMaxConcurrent: 8,
  });

  const cfg = readJson(CONFIG, {});
  cfg.agents = cfg.agents || {};
  cfg.agents.defaults = cfg.agents.defaults || {};
  cfg.agents.defaults.subagents = cfg.agents.defaults.subagents || {};

  if (!state.degraded && avail <= LOW_MB) {
    state.prevPrimary = cfg.agents.defaults?.model?.primary || PRIMARY_MODEL;
    state.prevMaxConcurrent = cfg.agents.defaults.maxConcurrent ?? 4;
    state.prevSubMaxConcurrent = cfg.agents.defaults.subagents.maxConcurrent ?? 8;

    applyDegraded(cfg, state);
    fs.writeFileSync(CONFIG, JSON.stringify(cfg, null, 2));
    state.degraded = true;
    state.lastAction = `degraded@${avail}MB`;
    writeJson(STATE, state);
    log(`[memory-guard] LOW mem=${avail}MB <= ${LOW_MB}MB -> degrade (primary=${FALLBACK_MODEL}, concurrency=1/1)`);
    restartGatewayBestEffort();
    return;
  }

  if (state.degraded && avail >= RECOVER_MB) {
    restoreNormal(cfg, state);
    fs.writeFileSync(CONFIG, JSON.stringify(cfg, null, 2));
    state.degraded = false;
    state.lastAction = `restored@${avail}MB`;
    writeJson(STATE, state);
    log(`[memory-guard] mem recovered=${avail}MB >= ${RECOVER_MB}MB -> restore primary/concurrency`);
    restartGatewayBestEffort();
    return;
  }

  log(`[memory-guard] steady mem=${avail}MB degraded=${state.degraded}`);
  state.lastSeenMB = avail;
  writeJson(STATE, state);
}

main();
