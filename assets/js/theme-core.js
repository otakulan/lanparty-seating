function getStoredTheme() {
  return localStorage.getItem('theme')
}

function setStoredTheme(theme) {
  localStorage.setItem('theme', theme)
}

function getLastLightTheme() {
  return localStorage.getItem('lastLightTheme')
}

function setLastLightTheme(theme) {
  localStorage.setItem('lastLightTheme', theme)
}

function getLastDarkTheme() {
  return localStorage.getItem('lastDarkTheme')
}

function setLastDarkTheme(theme) {
  localStorage.setItem('lastDarkTheme', theme)
}

function getCurrentTheme() {
  return document.documentElement.getAttribute('data-theme')
}

function setCurrentTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme)
}

function getThemesMeta() {
  const meta = document.querySelector('meta[name="themes"]')
  if (!meta) return null
  
  try {
    return JSON.parse(meta.content)
  } catch {
    return null
  }
}

function getThemesConfig() {
  const meta = getThemesMeta()
  if (meta) return meta
  
  return { light: ['light'], dark: ['dark'] }
}

function getAllThemes() {
  const config = getThemesConfig()
  return [...config.light, ...config.dark]
}

function getThemeCategory(theme) {
  const config = getThemesConfig()
  if (config.light.includes(theme)) return 'light'
  if (config.dark.includes(theme)) return 'dark'
  return null
}

function getDefaultTheme(category) {
  const config = getThemesConfig()
  return config[category]?.[0] || 'light'
}

function getLastUsedTheme(category) {
  if (category === 'light') {
    return getLastLightTheme() || getDefaultTheme('light')
  }
  return getLastDarkTheme() || getDefaultTheme('dark')
}

function setLastUsedTheme(theme) {
  const category = getThemeCategory(theme)
  if (category === 'light') {
    setLastLightTheme(theme)
  } else if (category === 'dark') {
    setLastDarkTheme(theme)
  }
}

function getOppositeCategoryTheme(currentTheme) {
  const category = getThemeCategory(currentTheme)
  if (category === 'light') {
    return getLastUsedTheme('dark')
  }
  if (category === 'dark') {
    return getLastUsedTheme('light')
  }
  return getDefaultTheme('light')
}

function getSystemTheme() {
  const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  return getDefaultTheme(isDark ? 'dark' : 'light')
}

function getEffectiveTheme() {
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

function isDarkTheme(theme) {
  return getThemeCategory(theme) === 'dark'
}

function updateAllToggleVisuals(theme) {
  const dark = isDarkTheme(theme)
  document.querySelectorAll('[phx-hook="ThemeToggle"]').forEach(el => {
    const checkbox = el.querySelector('.theme-controller')
    if (checkbox) checkbox.checked = dark
    el.classList.toggle('swap-active', dark)
  })
}

function updateAllDropdownVisuals(theme) {
  document.querySelectorAll('[phx-hook="ThemeDropdown"]').forEach(el => {
    el.querySelectorAll('input[type="radio"]').forEach(radio => {
      radio.checked = radio.value === theme
    })
  })
}

function applyTheme(theme) {
  setCurrentTheme(theme)
  setStoredTheme(theme)
  setLastUsedTheme(theme)
  updateAllToggleVisuals(theme)
  updateAllDropdownVisuals(theme)
}

function initLastUsedThemes() {
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

function initTheme() {
  const theme = getEffectiveTheme()
  setCurrentTheme(theme)
}

export {
  getStoredTheme,
  setStoredTheme,
  getLastLightTheme,
  setLastLightTheme,
  getLastDarkTheme,
  setLastDarkTheme,
  getCurrentTheme,
  setCurrentTheme,
  getThemesConfig,
  getAllThemes,
  getThemeCategory,
  getDefaultTheme,
  getLastUsedTheme,
  setLastUsedTheme,
  getOppositeCategoryTheme,
  getSystemTheme,
  getEffectiveTheme,
  isDarkTheme,
  updateAllToggleVisuals,
  updateAllDropdownVisuals,
  applyTheme,
  initLastUsedThemes,
  initTheme,
}