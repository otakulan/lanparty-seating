import SeatMapViewer from "../seat_map/seat_map_viewer_class"

export default {
  mounted() {
    this.runtime = new SeatMapViewer(this)
    
    this.handleEvent("seat_map_init", (payload) => {
      this.runtime.setPayload(payload.map)
      this.runtime.mount()
    })
    
    this.handleEvent("seat_map_update", (payload) => {
      this.runtime.update(payload.map)
      this.runtime.scheduleRender(false)
    })
  },

  destroyed() {
    this.runtime.destroy()
  }
}
