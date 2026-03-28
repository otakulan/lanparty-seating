import SeatMapViewer from "./seat_map_viewer_class"

export default {
  mounted() {
    this.runtime = new SeatMapViewer(this)
    this.runtime.mount()
  },

  updated() {
    this.runtime.update()
    this.runtime.scheduleRender(false)
  },

  destroyed() {
    this.runtime.destroy()
  }
}