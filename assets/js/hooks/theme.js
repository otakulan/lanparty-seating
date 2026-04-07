import {
  getStoredTheme,
  getCurrentTheme,
  getThemesConfig,
  getDefaultTheme,
  getOppositeCategoryTheme,
  getSystemTheme,
  getEffectiveTheme,
  updateAllToggleVisuals,
  updateAllDropdownVisuals,
  applyTheme,
  initLastUsedThemes,
} from '../theme-core.js'

export const ThemeToggle = {
  mounted() {
    this.prefersDark = window.matchMedia('(prefers-color-scheme: dark)')
    
    initLastUsedThemes()
    this.initTheme()
    this.bindEvents()
  },

  initTheme() {
    const theme = getEffectiveTheme()
    document.documentElement.setAttribute('data-theme', theme)
    updateAllToggleVisuals(theme)
  },

  bindEvents() {
    this.clickHandler = (e) => this.handleClick(e)
    this.storageHandler = (e) => this.handleStorageChange(e)
    this.systemThemeHandler = (e) => this.handleSystemThemeChange(e)
    
    this.el.addEventListener('click', this.clickHandler)
    window.addEventListener('storage', this.storageHandler)
    this.prefersDark.addEventListener('change', this.systemThemeHandler)
  },

  destroyed() {
    this.el.removeEventListener('click', this.clickHandler)
    window.removeEventListener('storage', this.storageHandler)
    this.prefersDark.removeEventListener('change', this.systemThemeHandler)
  },

  handleClick(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const currentTheme = getCurrentTheme()
    const nextTheme = getOppositeCategoryTheme(currentTheme)
    
    applyTheme(nextTheme)
  },

  handleStorageChange(event) {
    if (event.key !== 'theme' || !event.newValue) return
    
    document.documentElement.setAttribute('data-theme', event.newValue)
    updateAllToggleVisuals(event.newValue)
  },

  handleSystemThemeChange() {
    if (getStoredTheme()) return
    
    const theme = getSystemTheme()
    document.documentElement.setAttribute('data-theme', theme)
    updateAllToggleVisuals(theme)
  },
}

export const ThemeDropdown = {
  mounted() {
    const theme = getEffectiveTheme()
    this.setCurrentRadio(theme)
    this.bindEvents()
  },

  setCurrentRadio(theme) {
    this.el.querySelectorAll('input[type="radio"]').forEach(radio => {
      radio.checked = radio.value === theme
    })
  },

  bindEvents() {
    this.changeHandler = (e) => this.handleChange(e)
    this.storageHandler = (e) => this.handleStorageChange(e)
    
    this.el.addEventListener('change', this.changeHandler)
    window.addEventListener('storage', this.storageHandler)
  },

  destroyed() {
    this.el.removeEventListener('change', this.changeHandler)
    window.removeEventListener('storage', this.storageHandler)
  },

  handleChange(event) {
    if (event.target.type !== 'radio') return
    
    const theme = event.target.value
    applyTheme(theme)
  },

  handleStorageChange(event) {
    if (event.key !== 'theme' || !event.newValue) return
    this.setCurrentRadio(event.newValue)
  },
}

export default ThemeToggle