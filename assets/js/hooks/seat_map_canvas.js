import SeatMapViewer from "../seat_map/seat_map_viewer_class"

export default {
  mounted() {
    this.runtime = new SeatMapViewer(this)
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

  destroyed() {
    this.runtime.destroy()
  }
}
