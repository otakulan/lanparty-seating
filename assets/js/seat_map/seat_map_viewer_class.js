import Konva from "konva"
import { SeatMapBase, SCALE_BY, clamp, getCenter, getDistance } from "./seat_map_base"
import {
  SEAT_WIDTH,
  SEAT_HEIGHT,
  SEAT_SCALE,
  createSeatGroup,
  addSeatLabel,
  createTimerNode,
  createHitTarget,
  renderGroupBounds,
  renderGroupLabel,
  renderTeamLabel,
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
    window.removeEventListener("resize", this.handleResize)
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
  
  scaleStage(nextScale) {
    const clampedScale = clamp(nextScale, 0.3, 3)
    const center = { x: this.stage.width() / 2, y: this.stage.height() / 2 }
    const oldScale = this.stage.scaleX() || 1
    const pointTo = {
      x: (center.x - this.stage.x()) / oldScale,
      y: (center.y - this.stage.y()) / oldScale
    }
    
    this.stage.scale({ x: clampedScale, y: clampedScale })
    this.stage.position({
      x: center.x - pointTo.x * clampedScale,
      y: center.y - pointTo.y * clampedScale
    })
    this.stage.batchDraw()
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
    this.stage.on("dragstart", () => this.hitLayer.listening(false))
    this.stage.on("dragend", () => {
      this.hitLayer.listening(true)
      this.stage.batchDraw()
    })
    
    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(true)
    }
    window.addEventListener("resize", this.handleResize)
  }
  
  scheduleRender(resetView = false) {
    if (this.renderFrame) return
    this.renderFrame = requestAnimationFrame(() => {
      this.renderFrame = null
      this.renderScene(resetView)
    })
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
      
      if (seat.reservation_end_date) {
        const timerNode = createTimerNode(theme, palette)
        seatGroup.add(timerNode)
        this.timerNodes.set(seat.seat_slot_id, {
          node: timerNode,
          endDate: seat.reservation_end_date
        })
      }
      
      this.sceneLayer.add(seatGroup)
      
      const hitTarget = createHitTarget(seat, SEAT_SCALE)
      hitTarget.on("click tap", () => this.handleSeatClick(seat))
      this.hitLayer.add(hitTarget)
    }
  }
  
  renderGroups() {
    const theme = this.theme
    const groups = this.state.groups || []
    const seats = this.state.seats || []
    const teamAssignments = this.state.team_assignments || []
    
    for (const group of groups) {
      renderGroupBounds(this.sceneLayer, group, seats, theme)
      renderGroupLabel(this.sceneLayer, group, seats, teamAssignments, theme)
    }
  }
  
  renderTeamLabels() {
    const theme = this.theme
    const groups = this.state.groups || []
    const seats = this.state.seats || []
    
    for (const assignment of this.state.team_assignments || []) {
      renderTeamLabel(this.overlayLayer, assignment, groups, seats, theme)
    }
  }
  
  handleSeatClick(seat) {
    this.hook.pushEvent("seat_selected", {
      seat_slot_id: seat.seat_slot_id,
      label: seat.label,
      status: seat.status
    })
  }
  
  fitToStage(resetPosition) {
    const padding = 60
    const width = this.state.width || 1920
    const height = this.state.height || 1080
    const scale = Math.min(
      (this.stage.width() - padding) / width,
      (this.stage.height() - padding) / height,
      1.5
    )
    const clampedScale = clamp(scale, 0.3, 3)
    
    if (resetPosition) {
      this.stage.scale({ x: clampedScale, y: clampedScale })
      this.stage.position({
        x: (this.stage.width() - width * clampedScale) / 2,
        y: (this.stage.height() - height * clampedScale) / 2
      })
    }
    
    this.stage.batchDraw()
  }
  
  handleWheel(event) {
    event.evt.preventDefault()
    
    const oldScale = this.stage.scaleX() || 1
    const pointer = this.stage.getPointerPosition()
    const pointTo = {
      x: (pointer.x - this.stage.x()) / oldScale,
      y: (pointer.y - this.stage.y()) / oldScale
    }
    
    const direction = event.evt.deltaY > 0 ? 1 : -1
    const nextScale = direction > 0 ? oldScale / SCALE_BY : oldScale * SCALE_BY
    const clampedScale = clamp(nextScale, 0.3, 3)
    
    this.stage.scale({ x: clampedScale, y: clampedScale })
    this.stage.position({
      x: pointer.x - pointTo.x * clampedScale,
      y: pointer.y - pointTo.y * clampedScale
    })
    
    this.stage.batchDraw()
  }
  
  handleTouchMove(event) {
    const touchOne = event.evt.touches[0]
    const touchTwo = event.evt.touches[1]
    
    if (touchOne && touchTwo) {
      event.evt.preventDefault()
      this.stage.draggable(false)
      
      const pointOne = { x: touchOne.clientX, y: touchOne.clientY }
      const pointTwo = { x: touchTwo.clientX, y: touchTwo.clientY }
      const center = getCenter(pointOne, pointTwo)
      const distance = getDistance(pointOne, pointTwo)
      
      if (!this.lastTouchCenter) {
        this.lastTouchCenter = center
        this.lastTouchDistance = distance
        return
      }
      
      const scale = this.stage.scaleX() * (distance / this.lastTouchDistance)
      const clampedScale = clamp(scale, 0.3, 3)
      const pointTo = {
        x: (center.x - this.stage.x()) / this.stage.scaleX(),
        y: (center.y - this.stage.y()) / this.stage.scaleY()
      }
      
      this.stage.scale({ x: clampedScale, y: clampedScale })
      
      const dx = center.x - this.lastTouchCenter.x
      const dy = center.y - this.lastTouchCenter.y
      
      this.stage.position({
        x: center.x - pointTo.x * clampedScale + dx,
        y: center.y - pointTo.y * clampedScale + dy
      })
      
      this.lastTouchCenter = center
      this.lastTouchDistance = distance
      this.stage.batchDraw()
    } else {
      this.stage.draggable(true)
    }
  }
  
  handleTouchEnd() {
    this.lastTouchCenter = null
    this.lastTouchDistance = 0
    this.stage.draggable(true)
  }
}