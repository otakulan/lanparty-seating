import Konva from "konva"
import { SeatMapBase, clamp } from "./seat_map_base"
import {
  SEAT_WIDTH,
  SEAT_HEIGHT,
  SEAT_SCALE,
  createSeatGroup,
  addSeatLabel,
  createHitTarget,
  renderGroupBounds,
  renderGroupLabel,
  renderTeamLabel
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
    window.removeEventListener("resize", this.handleResize)
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
    
    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(true)
    }
    window.addEventListener("resize", this.handleResize)
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
    
    for (const seat of this.state.seats || []) {
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
  
  fitToStage(resetPosition) {
    const padding = 60
    const bounds = this.getContentBounds()
    const stageWidth = this.stage.width()
    const stageHeight = this.stage.height()
    
    if (bounds.width === 0 || bounds.height === 0) {
      return
    }
    
    const scale = Math.min(
      (stageWidth - padding) / bounds.width,
      (stageHeight - padding) / bounds.height,
      1.2
    )
    const clampedScale = clamp(scale, 0.3, 3)
    
    if (resetPosition) {
      this.stage.scale({ x: clampedScale, y: clampedScale })
      const scaledWidth = bounds.width * clampedScale
      const scaledHeight = bounds.height * clampedScale
      this.stage.position({
        x: (stageWidth - scaledWidth) / 2 - bounds.x * clampedScale,
        y: (stageHeight - scaledHeight) / 2 - bounds.y * clampedScale
      })
    }
    
    this.stage.batchDraw()
  }
}