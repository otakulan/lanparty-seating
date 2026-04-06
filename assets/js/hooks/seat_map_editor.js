import SeatMapEditor from "../seat_map/seat_map_editor_class"

export default {
  mounted() {
    this.runtime = new SeatMapEditor(this)
    this.initialized = false
    
    this.handleEvent("seat_map_init", (payload) => {
      if (this.initialized) return
      this.initialized = true
      this.runtime.setPayload(payload.map)
      this.runtime.mount()
    })
    
    this.handleEvent("seat_map_update", (payload) => {
      if (!this.initialized) return
      if (!payload.map || !payload.map.seats) return
      this.runtime.update(payload.map)
      this.runtime.scheduleRender(false)
    })
  },

  updated() {
    // Check if the canvas container was destroyed and needs re-initialization
    const container = this.el.querySelector('[data-seat-map-stage]')
    const hasContent = container && container.querySelector('.konvajs-content')
    
    if (!hasContent && this.initialized) {
      // Canvas was destroyed, re-mount it
      this.runtime.mount()
    }
  },

  destroyed() {
    this.runtime.destroy()
  }
}
