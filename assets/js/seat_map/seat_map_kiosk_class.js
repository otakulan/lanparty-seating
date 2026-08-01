import Konva from "konva"
import { SeatMapBase, clamp } from "./seat_map_base"
import {
  SEAT_WIDTH,
  SEAT_HEIGHT,
  SEAT_SCALE,
  createSeatGroup,
  addSeatLabel,
  createHitTarget
} from "./seat_map_renderer"

export default class SeatMapKiosk extends SeatMapBase {
  constructor(hook, options = {}) {
    super(hook, options)
    this.pickable = options.pickable === true
    this.showKeyboard = options.showKeyboard !== false
  }
  
  mount() {
    this.pickable = this.hook.el.dataset.pickable === "true"
    this.buildStage()
    this.setupThemeListener()
    this.renderScene(true)
  }
  
  destroy() {
    this.teardownResizeHandler()
    if (this.renderFrame) cancelAnimationFrame(this.renderFrame)
    super.destroy()
  }
  
  buildStage() {
    this.stage = new Konva.Stage({
      container: this.stageContainer,
      width: this.stageContainer.clientWidth,
      height: this.stageContainer.clientHeight,
      draggable: false
    })
    
    this.sceneLayer = new Konva.Layer({ listening: false })
    this.hitLayer = this.pickable ? new Konva.Layer() : null
    this.overlayLayer = new Konva.Layer({ listening: false })
    
    this.stage.add(this.sceneLayer)
    if (this.hitLayer) this.stage.add(this.hitLayer)
    this.stage.add(this.overlayLayer)
    
    this.setupResizeHandler()
  }
  
  renderScene(resetView) {
    this.sceneLayer.destroyChildren()
    if (this.hitLayer) this.hitLayer.destroyChildren()
    this.overlayLayer.destroyChildren()
    
    this.renderSeats()
    this.renderGroups()
    this.renderTeamLabels()
    
    // Cache entire layers as single images for best performance (kiosk is static)
    this.cacheLayers()
    
    if (resetView) {
      this.fitToStage(true)
    } else {
      this.stage.batchDraw()
    }
  }
  
  cacheLayers() {
    this.sceneLayer.cache()
    this.overlayLayer.cache()
  }
  
  renderSeats() {
    const theme = this.theme
    const statusColors = this.statusColors
    
    for (const seat of this.state.seats) {
      const palette = statusColors[seat.status] || statusColors.available
      const seatGroup = createSeatGroup(seat, palette, theme, {
        showKeyboard: this.showKeyboard
      })
      
      addSeatLabel(seatGroup, seat, theme, palette)
      
      this.sceneLayer.add(seatGroup)
      
      if (this.pickable && this.hitLayer) {
        const hitTarget = createHitTarget(seat, SEAT_SCALE)
        hitTarget.on("click tap", () => this.handleSeatClick(seat))
        this.hitLayer.add(hitTarget)
      }
    }
  }
  
  getGroupLayer() {
    return this.sceneLayer
  }
  
  handleSeatClick(seat) {
    if (this.pickable) {
      this.hook.pushEvent("seat_selected", {
        seat_slot_id: seat.seat_slot_id,
        label: seat.label,
        status: seat.status
      })
    }
  }
  
  getMaxScale() {
    return 3
  }
  
  fitToStage(resetPosition) {
    super.fitToStage(resetPosition, {
      maxVisibleScale: 1.2,
      minScaleOverride: 0.3,
      maxScaleOverride: 3
    })
  }
}