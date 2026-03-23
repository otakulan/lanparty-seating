import SeatMapRuntime from "./seat_map_runtime"

export default {
  mounted() {
    this.runtime = new SeatMapRuntime(this, { editable: false })
    this.runtime.mount()
  },

  updated() {
    this.runtime.update()
  },

  destroyed() {
    this.runtime.destroy()
  }
}
