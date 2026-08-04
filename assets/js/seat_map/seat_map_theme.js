/**
 * Theme configuration for seat map components.
 * Reads colors from the DaisyUI `--color-*` custom properties, which are already
 * oklch, so the canvas follows the active theme (light / dark / forest) live.
 */

import { getCurrentTheme, getThemeCategory } from "../theme-core.js"

function getCSSVariable(name, fallback) {
  if (typeof window === 'undefined') return fallback

  const value = getComputedStyle(document.documentElement).getPropertyValue(name)?.trim()
  return value || fallback
}

function hexToOklchComponents(hex) {
  const sanitized = hex.replace('#', '')
  const value = sanitized.length === 3
    ? sanitized.split('').map(c => c + c).join('')
    : sanitized

  const r = parseInt(value.slice(0, 2), 16) / 255
  const g = parseInt(value.slice(2, 4), 16) / 255
  const b = parseInt(value.slice(4, 6), 16) / 255

  if (!Number.isFinite(r) || !Number.isFinite(g) || !Number.isFinite(b)) return null

  const toLinear = c => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4))
  const lr = toLinear(r)
  const lg = toLinear(g)
  const lb = toLinear(b)

  const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
  const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
  const s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)

  const okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
  const okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
  const okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s

  const chroma = Math.hypot(okA, okB)
  const hue = (Math.atan2(okB, okA) * 180) / Math.PI

  return `${okL.toFixed(4)} ${chroma.toFixed(4)} ${(hue < 0 ? hue + 360 : hue).toFixed(2)}`
}

/**
 * Returns `color` with `alpha` applied, as an oklch() string.
 * Accepts oklch(), hex and rgb()/rgba() inputs.
 */
export function withAlpha(color, alpha) {
  if (!color) return `oklch(0 0 0 / ${alpha})`

  const value = String(color).trim()

  if (value.startsWith('oklch(')) {
    const components = value.slice(6, value.lastIndexOf(')')).split('/')[0].trim()
    return `oklch(${components} / ${alpha})`
  }

  if (value.startsWith('#')) {
    const components = hexToOklchComponents(value)
    return components ? `oklch(${components} / ${alpha})` : `oklch(0 0 0 / ${alpha})`
  }

  const numbers = value.match(/-?\d*\.?\d+/g)
  if ((value.startsWith('rgb(') || value.startsWith('rgba(')) && numbers?.length >= 3) {
    const [r, g, b] = numbers.map(Number)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }

  return value
}

export function isLightTheme() {
  if (typeof window === 'undefined') return false

  return getThemeCategory(getCurrentTheme()) === 'light'
}

export function getThemeColors() {
  const base100 = getCSSVariable('--color-base-100', 'oklch(0.22 0.01 250)')
  const base200 = getCSSVariable('--color-base-200', 'oklch(0.19 0.01 250)')
  const base300 = getCSSVariable('--color-base-300', 'oklch(0.32 0.01 250)')
  const baseContent = getCSSVariable('--color-base-content', 'oklch(0.93 0.01 250)')

  const success = getCSSVariable('--color-success', 'oklch(0.75 0.18 150)')
  const warning = getCSSVariable('--color-warning', 'oklch(0.8 0.16 82)')
  const error = getCSSVariable('--color-error', 'oklch(0.66 0.21 25)')
  const info = getCSSVariable('--color-info', 'oklch(0.72 0.13 215)')
  const primary = getCSSVariable('--color-primary', 'oklch(0.65 0.2 260)')

  return {
    background: base100,
    backgroundGradientStart: base100,
    backgroundGradientEnd: base200,
    borderColor: base300,
    gridColor: 'oklch(0.5 0.02 250 / 0.15)',
    panelBg: withAlpha(base100, 0.95),
    panelBorder: base300,
    textPrimary: baseContent,
    textSecondary: withAlpha(baseContent, 0.7),
    textMuted: withAlpha(baseContent, 0.45),
    accentGreen: success,
    accentCyan: info,
    accentAmber: warning,
    accentRed: error,
    fontFamily: "'JetBrains Mono', 'SF Mono', ui-monospace, Menlo, monospace",
    displayFont: "'JetBrains Mono', 'SF Pro Display', -apple-system, sans-serif",
    monitorFill: withAlpha(primary, 0.12),
    monitorStroke: withAlpha(primary, 0.35),
    // Derived from base-content, not neutral: neutral is dark on dark themes and
    // the hardware would be invisible against the background.
    keyboardFill: withAlpha(baseContent, 0.16),
    keyboardStroke: withAlpha(baseContent, 0.4),
    tableFill: withAlpha(baseContent, 0.12),
    tableStroke: withAlpha(baseContent, 0.4),
    lockBadge: warning,
    lockBadgeBg: withAlpha(base100, 0.9)
  }
}

export function getStatusColors() {
  const theme = getThemeColors()

  const palette = color => ({
    fill: theme.background,
    fillSecondary: theme.backgroundGradientEnd,
    stroke: color,
    text: color,
    glow: withAlpha(color, 0.35),
    accent: color
  })

  return {
    available: palette(theme.accentGreen),
    occupied: palette(theme.accentAmber),
    reserved: palette(theme.textSecondary),
    unavailable: palette(theme.accentRed),
    tournament: palette(theme.accentCyan)
  }
}

export const THEME = {
  get background() { return getThemeColors().background },
  get backgroundGradientStart() { return getThemeColors().backgroundGradientStart },
  get backgroundGradientEnd() { return getThemeColors().backgroundGradientEnd },
  get borderColor() { return getThemeColors().borderColor },
  get gridColor() { return getThemeColors().gridColor },
  get panelBg() { return getThemeColors().panelBg },
  get panelBorder() { return getThemeColors().panelBorder },
  get textPrimary() { return getThemeColors().textPrimary },
  get textSecondary() { return getThemeColors().textSecondary },
  get textMuted() { return getThemeColors().textMuted },
  get accentGreen() { return getThemeColors().accentGreen },
  get accentCyan() { return getThemeColors().accentCyan },
  get accentAmber() { return getThemeColors().accentAmber },
  get fontFamily() { return getThemeColors().fontFamily },
  get displayFont() { return getThemeColors().displayFont },
  get monitorFill() { return getThemeColors().monitorFill },
  get monitorStroke() { return getThemeColors().monitorStroke },
  get keyboardFill() { return getThemeColors().keyboardFill },
  get keyboardStroke() { return getThemeColors().keyboardStroke },
  get tableFill() { return getThemeColors().tableFill },
  get tableStroke() { return getThemeColors().tableStroke },
  get lockBadge() { return getThemeColors().lockBadge },
  get lockBadgeBg() { return getThemeColors().lockBadgeBg }
}

export const STATUS_COLORS = {
  get available() { return getStatusColors().available },
  get occupied() { return getStatusColors().occupied },
  get reserved() { return getStatusColors().reserved },
  get unavailable() { return getStatusColors().unavailable },
  get tournament() { return getStatusColors().tournament }
}

export function createThemeSnapshot() {
  return {
    theme: getThemeColors(),
    statusColors: getStatusColors(),
    isLight: isLightTheme()
  }
}
