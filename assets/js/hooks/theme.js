import {
  getCurrentTheme,
  getOppositeCategoryTheme,
  getEffectiveTheme,
  isDarkTheme,
  applyTheme,
  initLastUsedThemes,
  onThemeChange,
} from '../theme-core.js'

export const ThemeToggle = {
  mounted() {
    initLastUsedThemes()
    this.updateVisual(getEffectiveTheme())
    this.bindEvents()
  },

  // Toggled (on/checked) means that the theme is set to "dark"
  updateVisual(theme) {
    const dark = isDarkTheme(theme)
    const checkbox = this.el.querySelector('.theme-controller')
    if (checkbox) checkbox.checked = dark
    this.el.classList.toggle('swap-active', dark)
  },

  bindEvents() {
    this.clickHandler = (e) => this.handleClick(e)
    this.unsubscribeTheme = onThemeChange((theme) => this.updateVisual(theme))

    this.el.addEventListener('click', this.clickHandler)
  },

  destroyed() {
    this.el.removeEventListener('click', this.clickHandler)
    if (this.unsubscribeTheme) this.unsubscribeTheme()
  },

  handleClick(event) {
    event.preventDefault()
    event.stopPropagation()

    const currentTheme = getCurrentTheme()
    const nextTheme = getOppositeCategoryTheme(currentTheme)

    applyTheme(nextTheme)
  },
}

export const ThemeDropdown = {
  mounted() {
    this.updateVisual(getEffectiveTheme())
    this.bindEvents()
  },

  updateVisual(theme) {
    this.el.querySelectorAll('input[type="radio"]').forEach((radio) => {
      radio.checked = radio.value === theme
    })
  },

  bindEvents() {
    this.changeHandler = (e) => this.handleChange(e)
    this.unsubscribeTheme = onThemeChange((theme) => this.updateVisual(theme))

    this.el.addEventListener('change', this.changeHandler)
  },

  destroyed() {
    this.el.removeEventListener('change', this.changeHandler)
    if (this.unsubscribeTheme) this.unsubscribeTheme()
  },

  handleChange(event) {
    if (event.target.type !== 'radio') return

    applyTheme(event.target.value)

    const panel = this.el.querySelector('[popover]')
    if (panel?.matches(':popover-open')) panel.hidePopover()
  },
}

export default ThemeToggle
