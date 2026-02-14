#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || '/root';
const CONFIG = process.env.CONFIG || path.join(HOME, '.openclaw', 'openclaw.json');
const AUTH_PROFILES = process.env.AUTH_PROFILES || path.join(HOME, '.openclaw', 'agents', 'main', 'agent', 'auth-profiles.json');
const STATE_FILE = process.env.STATE_FILE || path.join(HOME, '.openclaw', 'watchdog-state', 'model-guard.json');
const LOG = process.env.LOG || path.join(HOME, '.openclaw', 'model-guard.log');

const PRIMARY = process.env.PRIMARY_MODEL || 'openai-codex/gpt-5.3-codex';
const FALLBACK = process.env.FALLBACK_MODEL || 'zai/glm-4.7';
const PROFILE_ID = process.env.OAUTH_PROFILE || 'openai-codex:default';

const ERROR_THRESHOLD = Number(process.env.ERROR_THRESHOLD || 5);
const UNHEALTHY_NEED = Number(process.env.UNHEALTHY_NEED || 3); // 连续N次异常才降级
const HEALTHY_NEED = Number(process.env.HEALTHY_NEED || 3);     // 连续N次健康才恢复
const DRY = process.argv.includes('--dry-run');
const SIMULATE_UNHEALTHY = process.argv.includes('--simulate-unhealthy');
const SIMULATE_HEALTHY = process.argv.includes('--simulate-healthy');

function now() { return Date.now(); }
function ts() { return new Date().toISOString(); }
function log(msg) {
  fs.mkdirSync(path.dirname(LOG), { recursive: true });
  fs.appendFileSync(LOG, `[${ts()}] ${msg}\n`);
  console.log(msg);
}

function readJson(p, d = {}) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return d; }
}
function writeJson(p, v) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, JSON.stringify(v, null, 2));
}

function codexHealth() {
  if (SIMULATE_UNHEALTHY) return { ok: false, reason: 'simulated-unhealthy' };
  if (SIMULATE_HEALTHY) return { ok: true, reason: 'simulated-healthy' };

  const ap = readJson(AUTH_PROFILES, {});
  const usage = ap.usageStats?.[PROFILE_ID] || {};
  const t = now();

  // 只看稳定可靠字段，不用 fragile 文本匹配（避免误判）
  if (usage.disabledUntil && Number(usage.disabledUntil) > t) {
    return { ok: false, reason: `disabledUntil=${usage.disabledUntil}` };
  }
  if (usage.cooldownUntil && Number(usage.cooldownUntil) > t) {
    return { ok: false, reason: `cooldownUntil=${usage.cooldownUntil}` };
  }
  if ((usage.errorCount || 0) >= ERROR_THRESHOLD) {
    return { ok: false, reason: `errorCount=${usage.errorCount}` };
  }

  return { ok: true, reason: 'healthy' };
}

function setPrimary(target) {
  const cfg = readJson(CONFIG, {});
  cfg.agents = cfg.agents || {};
  cfg.agents.defaults = cfg.agents.defaults || {};
  cfg.agents.defaults.model = cfg.agents.defaults.model || {};

  const current = cfg.agents.defaults.model.primary;
  if (current === target) return false;

  cfg.agents.defaults.model.primary = target;
  const fbs = Array.isArray(cfg.agents.defaults.model.fallbacks) ? cfg.agents.defaults.model.fallbacks : [];
  cfg.agents.defaults.model.fallbacks = [FALLBACK, ...fbs.filter(x => x !== FALLBACK)];

  if (!DRY) fs.writeFileSync(CONFIG, JSON.stringify(cfg, null, 2));
  return true;
}

function main() {
  const state = readJson(STATE_FILE, {
    unhealthyStreak: 0,
    healthyStreak: 0,
    lastSwitchByGuard: false,
    lastReason: '',
    lastRunAt: 0,
  });

  const cfg = readJson(CONFIG, {});
  const current = cfg?.agents?.defaults?.model?.primary || 'unknown';
  const h = codexHealth();

  if (!h.ok) {
    state.unhealthyStreak = (state.unhealthyStreak || 0) + 1;
    state.healthyStreak = 0;
    state.lastReason = h.reason;

    if (current === PRIMARY && state.unhealthyStreak >= UNHEALTHY_NEED) {
      const changed = setPrimary(FALLBACK);
      if (changed) {
        state.lastSwitchByGuard = true;
        log(`[guard-v2] unhealthy x${state.unhealthyStreak} (${h.reason}) -> switch to ${FALLBACK}${DRY ? ' [dry-run]' : ''}`);
      } else {
        log(`[guard-v2] unhealthy x${state.unhealthyStreak} (${h.reason}), already fallback`);
      }
    } else {
      log(`[guard-v2] unhealthy x${state.unhealthyStreak} (${h.reason}), hold current=${current}`);
    }
  } else {
    state.healthyStreak = (state.healthyStreak || 0) + 1;
    state.unhealthyStreak = 0;
    state.lastReason = h.reason;

    if (state.lastSwitchByGuard && current === FALLBACK && state.healthyStreak >= HEALTHY_NEED) {
      const changed = setPrimary(PRIMARY);
      if (changed) {
        state.lastSwitchByGuard = false;
        log(`[guard-v2] healthy x${state.healthyStreak} -> switch back to ${PRIMARY}${DRY ? ' [dry-run]' : ''}`);
      } else {
        log(`[guard-v2] healthy x${state.healthyStreak}, already primary`);
      }
    } else {
      log(`[guard-v2] healthy x${state.healthyStreak}, current=${current}`);
    }
  }

  state.lastRunAt = now();
  if (!DRY) writeJson(STATE_FILE, state);
}

main();
