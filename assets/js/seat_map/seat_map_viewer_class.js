import Konva from "konva"
import { SeatMapBase, SCALE_BY, clamp } from "./seat_map_base"
import {
  SEAT_WIDTH,
  SEAT_HEIGHT,
  SEAT_SCALE,
  createSeatGroup,
  addSeatLabel,
  createTimerNode,
  createHitTarget,
  startTimerUpdates
} from "./seat_map_renderer"

export default class SeatMapViewer extends SeatMapBase {
  constructor(hook, options = {}) {
    super(hook, options)
    this.timerNodes = new Map()
    this.timerInterval = null
    this.showKeyboard = options.showKeyboard !== false
  }
  
  mount() {
    this.buildStage()
    this.bindCommands()
    this.setupThemeListener()
    this.renderScene(true)
  }
  
  destroy() {
    this.el.removeEventListener("click", this.handleCommandClick)
    this.teardownResizeHandler()
    if (this.timerInterval) clearInterval(this.timerInterval)
    if (this.renderFrame) cancelAnimationFrame(this.renderFrame)
    super.destroy()
  }
  
  bindCommands() {
    this.handleCommandClick = (event) => {
      const button = event.target.closest("[data-seat-map-command]")
      if (!button || !this.el.contains(button)) return
      event.preventDefault()
      this.executeCommand(button.dataset.seatMapCommand)
    }
    this.el.addEventListener("click", this.handleCommandClick)
  }
  
  executeCommand(command) {
    switch (command) {
      case "zoom-in":
        this.scaleStage(this.stage.scaleX() * SCALE_BY)
        break
      case "zoom-out":
        this.scaleStage(this.stage.scaleX() / SCALE_BY)
        break
      case "reset-view":
        this.fitToStage(true)
        break
    }
  }
  
  getMaxScale() {
    return 3
  }
  
  buildStage() {
    this.stage = new Konva.Stage({
      container: this.stageContainer,
      width: this.stageContainer.clientWidth,
      height: this.stageContainer.clientHeight,
      draggable: true
    })
    
    this.sceneLayer = new Konva.Layer({ listening: false })
    this.hitLayer = new Konva.Layer()
    this.overlayLayer = new Konva.Layer({ listening: false })
    
    this.stage.add(this.sceneLayer)
    this.stage.add(this.hitLayer)
    this.stage.add(this.overlayLayer)
    
    this.stage.on("wheel", (e) => this.handleWheel(e))
    this.stage.on("touchmove", (e) => this.handleTouchMove(e))
    this.stage.on("touchend", () => this.handleTouchEnd())
    this.stage.on("dragmove", () => this.constrainStageDrag())
    this.stage.on("dragstart", () => this.hitLayer.listening(false))
    this.stage.on("dragend", () => {
      this.hitLayer.listening(true)
      this.stage.batchDraw()
    })
    
    this.setupResizeHandler()
  }
  
  renderScene(resetView) {
    this.sceneLayer.destroyChildren()
    this.hitLayer.destroyChildren()
    this.overlayLayer.destroyChildren()
    this.timerNodes.clear()
    
    this.renderSeats()
    this.renderGroups()
    this.renderTeamLabels()
    
    if (this.timerNodes.size > 0) {
      this.timerInterval = startTimerUpdates(this.timerNodes, this.sceneLayer)
    }
    
    if (resetView) {
      this.fitToStage(true)
    } else {
      this.stage.batchDraw()
    }
  }
  
  renderSeats() {
    const theme = this.theme
    const statusColors = this.statusColors
    
    for (const seat of this.state.seats || []) {
      const palette = statusColors[seat.status] || statusColors.available
      const seatGroup = createSeatGroup(seat, palette, theme, {
        showKeyboard: this.showKeyboard
      })
      
      addSeatLabel(seatGroup, seat, theme, palette)
      
      const hasTimer = !!seat.reservation_end_date
      
      if (hasTimer) {
        const timerNode = createTimerNode(theme, palette)
        seatGroup.add(timerNode)
        this.timerNodes.set(seat.seat_slot_id, { node: timerNode, endDate: seat.reservation_end_date })
      }
      
      this.sceneLayer.add(seatGroup)
      
      const hitTarget = createHitTarget(seat, SEAT_SCALE)
      hitTarget.on("click tap", () => this.handleSeatClick(seat))
      this.hitLayer.add(hitTarget)
    }
  }
  
  getGroupLayer() {
    return this.sceneLayer
  }
  
  handleSeatClick(seat) {
    this.hook.pushEvent("seat_selected", {
      seat_slot_id: seat.seat_slot_id,
      label: seat.label,
      status: seat.status
})
  }
  
  fitToStage(resetPosition) {
    super.fitToStage(resetPosition, { updateDraggable: true })
  }
  
  handleWheel(event) {
    super.handleWheel(event, { updateDraggable: true, hitLayer: this.hitLayer })
  }
  
  handleTouchMove(event) {
    super.handleTouchMove(event)
    
    if (event.evt.touches[0] && event.evt.touches[1]) {
      // During pinch-zoom: update draggable state
      this.stage.draggable(!this.canvasFitsInViewport())
    } else {
      // Single touch: restore draggable state
      this.stage.draggable(!this.canvasFitsInViewport())
    }
  }
  
  handleTouchEnd() {
    super.handleTouchEnd()
    this.stage.draggable(!this.canvasFitsInViewport())
  }
}