import SeatMapKiosk from "../seat_map/seat_map_kiosk_class"

export default {
  mounted() {
    this.runtime = new SeatMapKiosk(this)
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