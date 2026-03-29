import SeatMapEditor from "../seat_map/seat_map_editor_class"

export default {
  mounted() {
    this.lastPayload = this.el.dataset.seatMap
    this.runtime = new SeatMapEditor(this)
    this.runtime.mount()
  },

  updated() {
    const container = this.el.querySelector('[data-seat-map-stage]')
    const hasContent = container && container.querySelector('.konvajs-content')
    
    if (!hasContent) {
      this.runtime.destroy()
      this.runtime = new SeatMapEditor(this)
      this.runtime.mount()
    } else {
      const newPayload = this.el.dataset.seatMap
      if (newPayload !== this.lastPayload) {
        this.lastPayload = newPayload
        this.runtime.update()
        this.runtime.scheduleRender(false)
      }
    }
  },

  destroyed() {
    this.runtime.destroy()
  }
}