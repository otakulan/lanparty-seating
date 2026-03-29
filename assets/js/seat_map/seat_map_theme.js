/**
 * Theme configuration for seat map components.
 * Reads colors from CSS custom properties (DaisyUI theme variables).
 * Supports automatic light/dark theme switching.
 */

function getCSSVariable(name, fallback) {
  if (typeof window === 'undefined') return fallback
  
  const value = getComputedStyle(document.documentElement).getPropertyValue(name)?.trim()
  return value || fallback
}

function hexToRgba(hex, alpha) {
  if (!hex) return `rgba(0, 0, 0, ${alpha})`
  
  hex = hex.replace('#', '')
  if (hex.length === 3) {
    hex = hex.split('').map(c => c + c).join('')
  }
  
  const r = parseInt(hex.slice(0, 2), 16)
  const g = parseInt(hex.slice(2, 4), 16)
  const b = parseInt(hex.slice(4, 6), 16)
  
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

function isLightTheme() {
  if (typeof window === 'undefined') return false
  
  const theme = getCSSVariable('--fallback-b1', '#1d232a')
  return theme && (theme.startsWith('#f') || theme.startsWith('#e') || theme.startsWith('#d') || 
         theme.startsWith('#c') || theme.startsWith('#b') || theme.startsWith('#a') ||
         theme === '#ffffff' || theme === '#fafafa' || theme === '#f5f5f5')
}

export function getThemeColors() {
  const light = isLightTheme()
  
  const baseBg = getCSSVariable('--fallback-b1', '#0d1117')
  const baseBgSecondary = getCSSVariable('--fallback-b2', '#161b22')  
  const baseBorder = getCSSVariable('--fallback-bc', '#30363d')
  const baseContent = getCSSVariable('--fallback-bc', '#e6edf3')
  const baseContentMuted = getCSSVariable('--fallback-bc', '#8b949e')
  
  const success = getCSSVariable('--fallback-su', '#22c55e')
  const warning = getCSSVariable('--fallback-wa', '#f59e0b')
  const error = getCSSVariable('--fallback-er', '#ef4444')
  const info = getCSSVariable('--fallback-in', '#06b6d4')
  
  return {
    background: baseBg,
    backgroundGradientStart: light ? '#ffffff' : baseBg,
    backgroundGradientEnd: light ? '#f1f5f9' : baseBgSecondary,
    borderColor: baseBorder,
    gridColor: light ? 'rgba(100, 116, 139, 0.15)' : 'rgba(48, 54, 61, 0.4)',
    panelBg: light ? 'rgba(248, 250, 252, 0.95)' : 'rgba(22, 27, 34, 0.95)',
    panelBorder: baseBorder,
    textPrimary: light ? '#1e293b' : '#e6edf3',
    textSecondary: light ? '#475569' : '#8b949e',
    textMuted: light ? '#94a3b8' : '#6e7681',
    accentGreen: success,
    accentCyan: info,
    accentAmber: warning,
    fontFamily: "'JetBrains Mono', 'SF Mono', ui-monospace, Menlo, monospace",
    displayFont: "'JetBrains Mono', 'SF Pro Display', -apple-system, sans-serif",
    monitorFill: light ? 'rgba(59, 130, 246, 0.1)' : 'rgba(96, 165, 250, 0.1)',
    monitorStroke: light ? 'rgba(59, 130, 246, 0.3)' : 'rgba(96, 165, 250, 0.2)',
    keyboardFill: light ? 'rgba(100, 116, 139, 0.1)' : 'rgba(139, 148, 158, 0.1)',
    keyboardStroke: light ? 'rgba(100, 116, 139, 0.2)' : 'rgba(139, 148, 158, 0.2)'
  }
}

export function getStatusColors() {
  const theme = getThemeColors()
  const isLight = isLightTheme()
  
  const success = getCSSVariable('--fallback-su', '#22c55e')
  const warning = getCSSVariable('--fallback-wa', '#f59e0b')
  const error = getCSSVariable('--fallback-er', '#ef4444')
  const neutral = getCSSVariable('--fallback-n', '#6b7280')
  const info = getCSSVariable('--fallback-in', '#06b6d4')
  
  const baseFill = isLight ? '#ffffff' : '#0d1117'
  const baseFillSecondary = isLight ? '#f1f5f9' : '#161b22'
  
  return {
    available: {
      fill: baseFill,
      fillSecondary: baseFillSecondary,
      stroke: success,
      text: success,
      glow: hexToRgba(success, isLight ? 0.4 : 0.35),
      accent: isLight ? '#16a34a' : '#4ade80'
    },
    occupied: {
      fill: baseFill,
      fillSecondary: baseFillSecondary,
      stroke: warning,
      text: warning,
      glow: hexToRgba(warning, isLight ? 0.4 : 0.35),
      accent: isLight ? '#d97706' : '#fbbf24'
    },
    reserved: {
      fill: baseFill,
      fillSecondary: baseFillSecondary,
      stroke: neutral,
      text: isLight ? '#4b5563' : '#9ca3af',
      glow: hexToRgba(neutral, isLight ? 0.3 : 0.3),
      accent: isLight ? '#6b7280' : '#9ca3af'
    },
    unavailable: {
      fill: baseFill,
      fillSecondary: baseFillSecondary,
      stroke: error,
      text: error,
      glow: hexToRgba(error, isLight ? 0.4 : 0.35),
      accent: isLight ? '#dc2626' : '#f87171'
    },
    tournament: {
      fill: baseFill,
      fillSecondary: baseFillSecondary,
      stroke: info,
      text: info,
      glow: hexToRgba(info, isLight ? 0.4 : 0.35),
      accent: isLight ? '#0891b2' : '#22d3ee'
    }
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
  get keyboardStroke() { return getThemeColors().keyboardStroke }
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