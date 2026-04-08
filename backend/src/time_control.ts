export type TimeControlCategory = 'bullet' | 'blitz' | 'rapid' | 'classical' | 'unknown'

export const DEFAULT_TIME_CONTROL = '5+3'

export const STANDARD_TIME_CONTROLS = [
  // ── BULLET ──
  '1+0',
  '1+1',
  '2+1',
  // ── BLITZ ──
  '3+0',
  '3+2',
  '5+0',
  '5+3',
  '5+5',
  '10+0',
  // ── RAPID ──
  '10+5',
  '10+10',
  '15+0',
  '15+10',
  '20+10',
  '25+10',
  // ── CLASSICAL ──
  '30+0',
  '60+30',
] as const

export const TIME_CONTROL_LABELS: Record<typeof STANDARD_TIME_CONTROLS[number], string> = {
  // ── BULLET ──
  '1+0': 'Hyperblitz',
  '1+1': 'Bullet',
  '2+1': 'Bullet',
  // ── BLITZ ──
  '3+0': 'Blitz',
  '3+2': 'Blitz',
  '5+0': 'Blitz',
  '5+3': 'Blitz',
  '5+5': 'Blitz',
  '10+0': 'Blitz',
  // ── RAPID ──
  '10+5': 'Rapid',
  '10+10': 'Rapid',
  '15+0': 'Rapid',
  '15+10': 'Rapid',
  '20+10': 'Rapid',
  '25+10': 'Rapid',
  // ── CLASSICAL ──
  '30+0': 'Classical',
  '60+30': 'Classical',
}

export const TIME_CONTROL_DESCRIPTIONS: Record<
  typeof STANDARD_TIME_CONTROLS[number],
  string
> = {
  // ── BULLET ──
  '1+0': '⚡ Ultra-fast lightning chess | Pure reflex test',
  '1+1': '🚀 Bullet with 1-second buffer | Skill vs speed',
  '2+1': '💨 Very quick with perfect increment | Popular online',
  // ── BLITZ ──
  '3+0': '🎲 Classic online blitz | Maximum tempo pressure',
  '3+2': '⚡ Most popular blitz | Speed + small safety net',
  '5+0': '🔥 Standard blitz game | Fast tactical play',
  '5+3': '✨ Tactical blitz with increment | Balanced intensity',
  '5+5': '🎯 Comfortable blitz | Tournament standard',
  '10+0': '🌋 Long blitz | Deeper strategy possible',
  // ── RAPID ──
  '10+5': '🎖️ Popular rapid format | Balanced time/increment',
  '10+10': '🏅 Extended rapid | Plenty of thinking time',
  '15+0': '♖ No-increment rapid | Skill depth test',
  '15+10': '👑 FIDE rapid standard | Serious tournament play',
  '20+10': '⚜️ Club championship | Strong players preferred',
  '25+10': '🏆 International rapid | Premium experience',
  // ── CLASSICAL ──
  '30+0': '📖 Classical online | Deep analytical play',
  '60+30': '♕ Grandmaster-style | Maximum depth & precision',
}

export const TIME_CONTROL_CATEGORIES: Record<
  typeof STANDARD_TIME_CONTROLS[number],
  TimeControlCategory
> = {
  // ── BULLET ──
  '1+0': 'bullet',
  '1+1': 'bullet',
  '2+1': 'bullet',
  // ── BLITZ ──
  '3+0': 'blitz',
  '3+2': 'blitz',
  '5+0': 'blitz',
  '5+3': 'blitz',
  '5+5': 'blitz',
  '10+0': 'blitz',
  // ── RAPID ──
  '10+5': 'rapid',
  '10+10': 'rapid',
  '15+0': 'rapid',
  '15+10': 'rapid',
  '20+10': 'rapid',
  '25+10': 'rapid',
  // ── CLASSICAL ──
  '30+0': 'classical',
  '60+30': 'classical',
}

export function normalizeTimeControl(timeControl: string): string {
  const raw = timeControl?.toString().trim().toLowerCase() ?? ''
  if (!raw.length) return DEFAULT_TIME_CONTROL

  let base = 0
  let increment = 0

  if (raw.includes('+')) {
    const parts = raw.split('+').map((part) => part.trim())
    base = parseInt(parts[0], 10)
    increment = parts.length > 1 ? parseInt(parts[1], 10) : 0
  } else if (raw.includes('_')) {
    const parts = raw.split('_').map((part) => part.trim())
    if (parts.length >= 2) {
      const maybeInc = parseInt(parts[parts.length - 1], 10)
      const maybeBase = parseInt(parts[parts.length - 2], 10)
      base = Number.isFinite(maybeBase) ? maybeBase : 0
      increment = Number.isFinite(maybeInc) ? maybeInc : 0
    }
  } else {
    const maybeBase = parseInt(raw, 10)
    if (Number.isFinite(maybeBase)) {
      base = maybeBase
      increment = 0
    }
  }

  if (!Number.isFinite(base) || base <= 0 || !Number.isFinite(increment) || increment < 0) {
    return DEFAULT_TIME_CONTROL
  }

  const normalized = `${base}+${increment}`
  return STANDARD_TIME_CONTROLS.includes(normalized as typeof STANDARD_TIME_CONTROLS[number])
    ? normalized
    : DEFAULT_TIME_CONTROL
}

export function isValidTimeControl(timeControl: string): boolean {
  return STANDARD_TIME_CONTROLS.includes(normalizeTimeControl(timeControl) as typeof STANDARD_TIME_CONTROLS[number])
}

export function classifyTimeControl(timeControl: string): TimeControlCategory {
  const normalized = normalizeTimeControl(timeControl) as typeof STANDARD_TIME_CONTROLS[number]
  return TIME_CONTROL_CATEGORIES[normalized] ?? 'unknown'
}

export function parseTimeControl(timeControl: string) {
  const normalized = normalizeTimeControl(timeControl)
  const [base, inc] = normalized.split('+').map((value) => parseInt(value, 10))
  return {
    baseSeconds: (Number.isFinite(base) ? base : 10) * 60,
    incrementSeconds: Number.isFinite(inc) ? inc : 0,
    normalized,
    category: classifyTimeControl(normalized),
    label: TIME_CONTROL_LABELS[normalized as typeof STANDARD_TIME_CONTROLS[number]],
    description: TIME_CONTROL_DESCRIPTIONS[normalized as typeof STANDARD_TIME_CONTROLS[number]],
  }
}
