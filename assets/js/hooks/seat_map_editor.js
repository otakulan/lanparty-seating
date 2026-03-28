import SeatMapEditor from "./seat_map_editor_class"

export default {
  mounted() {
    this.runtime = new SeatMapEditor(this)
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