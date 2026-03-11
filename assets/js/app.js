import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import Alpine from "alpinejs"
import focus from "@alpinejs/focus"
import BluetoothProvisioning from "./hooks/bluetooth_provisioning"
import ButtonGridHook from "./hooks/button_grid_hook"
import SortableListHook from "./hooks/sortable_list_hook"

window.Alpine = Alpine
Alpine.plugin(focus)
Alpine.start()

// LiveView Hooks
let Hooks = {
  BluetoothProvisioning,
  ButtonGridHook,
  SortableListHook
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
