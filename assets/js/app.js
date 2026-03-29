import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import Alpine from "alpinejs"
import focus from "@alpinejs/focus"
import BluetoothProvisioning from "./hooks/bluetooth_provisioning"
import SeatMapCanvas from "./hooks/seat_map_canvas"
import SeatMapEditor from "./hooks/seat_map_editor"
import SeatMapKiosk from "./hooks/seat_map_kiosk"

window.Alpine = Alpine
Alpine.plugin(focus)
Alpine.start()

// LiveView Hooks
let Hooks = {
  BluetoothProvisioning,
  SeatMapCanvas,
  SeatMapEditor,
  SeatMapKiosk,
  
  ThemeToggle: {
    mounted() {
      const stored = localStorage.getItem('theme')
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      const theme = stored || (prefersDark ? 'dark' : 'light')
      const checkbox = this.el.querySelector('.theme-controller')
      
      this.updateVisualState(theme)
      
      this.el.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()
        
        const currentTheme = document.documentElement.getAttribute('data-theme')
        const themes = ['light', 'dark']
        const currentIndex = themes.indexOf(currentTheme)
        const nextIndex = (currentIndex + 1) % themes.length
        const newTheme = themes[nextIndex]
        
        document.documentElement.setAttribute('data-theme', newTheme)
        localStorage.setItem('theme', newTheme)
        
        // Update all theme toggles on the page
        document.querySelectorAll('[phx-hook="ThemeToggle"]').forEach(el => {
          const cb = el.querySelector('.theme-controller')
          if (cb) cb.checked = (newTheme === 'dark')
          if (newTheme === 'dark') {
            el.classList.add('swap-active')
          } else {
            el.classList.remove('swap-active')
          }
        })
      })
    },
    
    updateVisualState(theme) {
      const checkbox = this.el.querySelector('.theme-controller')
      if (checkbox) {
        checkbox.checked = (theme === 'dark')
      }
      if (theme === 'dark') {
        this.el.classList.add('swap-active')
      } else {
        this.el.classList.remove('swap-active')
      }
    }
  }
}

// Auto-focus input when mounted (used for modal badge inputs)
Hooks.AutoFocus = {
  mounted() {
    this.el.focus()
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  },
  hooks: Hooks
})

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// The latency simulator is enabled for the duration of the browser session.
// Call disableLatencySim() to disable:
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
