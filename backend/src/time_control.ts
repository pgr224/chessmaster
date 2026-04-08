export type TimeControlCategory = 'bullet' | 'blitz' | 'rapid' | 'classical' | 'unknown'

export const DEFAULT_TIME_CONTROL = '10+0'

export const STANDARD_TIME_CONTROLS = [
  '1+0',
  '2+1',
  '3+0',
  '3+2',
  '5+0',
  '5+3',
  '10+0',
  '10+5',
  '10+10',
  '15+0',
  '15+10',
  '30+0',
] as const

export const TIME_CONTROL_LABELS: Record<typeof STANDARD_TIME_CONTROLS[number], string> = {
  '1+0': 'Bullet',
  '2+1': 'Bullet',
  '3+0': 'Blitz',
  '3+2': 'Blitz',
  '5+0': 'Blitz',
  '5+3': 'Blitz',
  '10+0': 'Rapid',
  '10+5': 'Rapid',
  '10+10': 'Rapid',
  '15+0': 'Rapid',
  '15+10': 'Rapid',
  '30+0': 'Classical',
}

export const TIME_CONTROL_DESCRIPTIONS: Record<
  typeof STANDARD_TIME_CONTROLS[number],
  string
> = {
  '1+0': 'Fast action with 1 minute per side.',
  '2+1': 'Very quick with a small increment.',
  '3+0': 'Classic online blitz.',
  '3+2': 'Blitz with a small increment.',
  '5+0': 'Standard blitz game.',
  '5+3': 'Tactical blitz with increment.',
  '10+0': 'Speedy rapid play without increment.',
  '10+5': 'Balanced rapid with 5s increment.',
  '10+10': 'Long rapid with comfortable increment.',
  '15+0': 'Long rapid for deeper strategy.',
  '15+10': 'Popular rapid with increment.',
  '30+0': 'Classical online tempo for thoughtful play.',
}

export const TIME_CONTROL_CATEGORIES: Record<
  typeof STANDARD_TIME_CONTROLS[number],
  TimeControlCategory
> = {
  '1+0': 'bullet',
  '2+1': 'bullet',
  '3+0': 'blitz',
  '3+2': 'blitz',
  '5+0': 'blitz',
  '5+3': 'blitz',
  '10+0': 'rapid',
  '10+5': 'rapid',
  '10+10': 'rapid',
  '15+0': 'rapid',
  '15+10': 'rapid',
  '30+0': 'classical',
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
