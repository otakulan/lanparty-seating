import SeatMapKiosk from "../seat_map/seat_map_kiosk_class"

export default {
  mounted() {
    this.runtime = new SeatMapKiosk(this)
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
    const container = this.el.querySelector('[data-seat-map-stage]')
    const hasContent = container && container.querySelector('.konvajs-content')
    
    if (!hasContent && this.initialized) {
      this.runtime.mount()
    }
  },

  destroyed() {
    this.runtime.destroy()
  }
}
