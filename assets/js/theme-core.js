export function getStoredTheme() {
  return localStorage.getItem('theme')
}

export function setStoredTheme(theme) {
  localStorage.setItem('theme', theme)
}

export function getLastLightTheme() {
  return localStorage.getItem('lastLightTheme')
}

export function setLastLightTheme(theme) {
  localStorage.setItem('lastLightTheme', theme)
}

export function getLastDarkTheme() {
  return localStorage.getItem('lastDarkTheme')
}

export function setLastDarkTheme(theme) {
  localStorage.setItem('lastDarkTheme', theme)
}

export function getCurrentTheme() {
  return document.documentElement.getAttribute('data-theme')
}

export function setCurrentTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme)
}

export function getThemesMeta() {
  const meta = document.querySelector('meta[name="themes"]')
  if (!meta) return null
  
  try {
    return JSON.parse(meta.content)
  } catch {
    return null
  }
}

export function getThemesConfig() {
  const meta = getThemesMeta()
  if (meta) return meta
  
  return { light: ['light'], dark: ['dark'] }
}

export function getAllThemes() {
  const config = getThemesConfig()
  return [...config.light, ...config.dark]
}

export function getThemeCategory(theme) {
  const config = getThemesConfig()
  if (config.light.includes(theme)) return 'light'
  if (config.dark.includes(theme)) return 'dark'
  return null
}

export function getDefaultTheme(category) {
  const config = getThemesConfig()
  return config[category]?.[0] || 'light'
}

export function getLastUsedTheme(category) {
  if (category === 'light') {
    return getLastLightTheme() || getDefaultTheme('light')
  }
  return getLastDarkTheme() || getDefaultTheme('dark')
}

export function setLastUsedTheme(theme) {
  const category = getThemeCategory(theme)
  if (category === 'light') {
    setLastLightTheme(theme)
  } else if (category === 'dark') {
    setLastDarkTheme(theme)
  }
}

export function getOppositeCategoryTheme(currentTheme) {
  const category = getThemeCategory(currentTheme)
  if (category === 'light') {
    return getLastUsedTheme('dark')
  }
  if (category === 'dark') {
    return getLastUsedTheme('light')
  }
  return getDefaultTheme('light')
}

export function getSystemTheme() {
  const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  return getDefaultTheme(isDark ? 'dark' : 'light')
}

export function getEffectiveTheme() {
  const stored = getStoredTheme()
  if (stored) return stored
  
  const lastLight = getLastLightTheme()
  const lastDark = getLastDarkTheme()
  
  if (lastLight || lastDark) {
    const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    if (isDark && lastDark) return lastDark
    if (!isDark && lastLight) return lastLight
    return isDark ? getDefaultTheme('dark') : getDefaultTheme('light')
  }
  
  return getSystemTheme()
}

export function isDarkTheme(theme) {
  return getThemeCategory(theme) === 'dark'
}

export function updateAllToggleVisuals(theme) {
  const dark = isDarkTheme(theme)
  document.querySelectorAll('[phx-hook="ThemeToggle"]').forEach(el => {
    const checkbox = el.querySelector('.theme-controller')
    if (checkbox) checkbox.checked = dark
    el.classList.toggle('swap-active', dark)
  })
}

export function updateAllDropdownVisuals(theme) {
  document.querySelectorAll('[phx-hook="ThemeDropdown"]').forEach(el => {
    el.querySelectorAll('input[type="radio"]').forEach(radio => {
      radio.checked = radio.value === theme
    })
  })
}

export function onThemeChange(callback) {
  if (typeof window === 'undefined') return () => {}
  
  const handler = (e) => callback(e.detail.theme, e.detail)
  window.addEventListener('lanparty:themechange', handler)
  return () => window.removeEventListener('lanparty:themechange', handler)
}

export function dispatchThemeChange(theme) {
  if (typeof window === 'undefined') return
  
  const category = getThemeCategory(theme)
  window.dispatchEvent(new CustomEvent('lanparty:themechange', {
    detail: {
      theme,
      category,
      isLight: category === 'light'
    }
  }))
}

export function applyTheme(theme) {
  setCurrentTheme(theme)
  setStoredTheme(theme)
  setLastUsedTheme(theme)
  updateAllToggleVisuals(theme)
  updateAllDropdownVisuals(theme)
  dispatchThemeChange(theme)
}

export function initLastUsedThemes() {
  const config = getThemesConfig()
  const currentTheme = getStoredTheme()
  
  if (currentTheme) {
    setLastUsedTheme(currentTheme)
  } else {
    if (!getLastLightTheme() && config.light.length > 0) {
      setLastLightTheme(config.light[0])
    }
    if (!getLastDarkTheme() && config.dark.length > 0) {
      setLastDarkTheme(config.dark[0])
    }
  }
}

export function initTheme() {
  const theme = getEffectiveTheme()
  setCurrentTheme(theme)
}