import Konva from "konva"
import { SeatMapBase, SCALE_BY, clamp, countdownLabel, groupBounds } from "./seat_map_base"

const SEAT_WIDTH = 64
const SEAT_HEIGHT = 64

function renderSeatShape(seatGroup, seat, palette, scale, theme, showKeyboard = true) {
  const w = SEAT_WIDTH * scale
  const h = SEAT_HEIGHT * scale
  
  seatGroup.add(new Konva.Rect({
    x: -w / 2,
    y: -h * 0.6,
    width: w,
    height: h * 0.75,
    cornerRadius: 6,
    fillLinearGradientStartPoint: { x: 0, y: 0 },
    fillLinearGradientEndPoint: { x: w, y: h * 0.75 },
    fillLinearGradientColorStops: [0, palette.fillSecondary, 0.5, palette.fill, 1, palette.fill],
    stroke: palette.stroke,
    strokeWidth: 2,
    shadowColor: palette.glow,
    shadowBlur: 12,
    shadowOpacity: 0.6,
    perfectDrawEnabled: false
  }))
  
  seatGroup.add(new Konva.Rect({
    x: -w * 0.38,
    y: -h * 0.5,
    width: w * 0.76,
    height: h * 0.4,
    cornerRadius: 3,
    fill: theme.monitorFill,
    stroke: theme.monitorStroke,
    strokeWidth: 1,
    perfectDrawEnabled: false
  }))
  
  seatGroup.add(new Konva.Circle({
    x: w * 0.32,
    y: -h * 0.05,
    radius: 3,
    fill: palette.accent,
    perfectDrawEnabled: false
  }))
  
  if (showKeyboard) {
    seatGroup.add(new Konva.Rect({
      x: -w * 0.45,
      y: h * 0.22,
      width: w * 0.9,
      height: h * 0.28,
      cornerRadius: 4,
      fill: theme.keyboardFill,
      stroke: theme.keyboardStroke,
      strokeWidth: 1,
      perfectDrawEnabled: false
    }))
  }
}

export default class SeatMapViewer extends SeatMapBase {
  constructor(hook, options = {}) {
    super(hook, options)
    this.showKeyboard = options.showKeyboard !== false
    this.timerNodes = new Map()
    this.renderFrame = null
    this.renderTick = null
    this.lastTouchCenter = null
    this.lastTouchDistance = 0
  }
  
  mount() {
    this.buildStage()
    this.bindCommands()
    this.setupThemeListener()
    this.startTicking()
    this.renderScene(true)
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
  
  destroy() {
    this.el.removeEventListener("click", this.handleCommandClick)
    window.removeEventListener("resize", this.handleResize)
    clearInterval(this.renderTick)
    if (this.renderFrame) window.cancelAnimationFrame(this.renderFrame)
    super.destroy()
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
    const contentPoint = {
      x: (center.x - this.stage.x()) / oldScale,
      y: (center.y - this.stage.y()) / oldScale
    }
    
    this.stage.scale({ x: clampedScale, y: clampedScale })
    this.stage.position({
      x: center.x - contentPoint.x * clampedScale,
      y: center.y - contentPoint.y * clampedScale
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
    
    this.backgroundLayer = new Konva.Layer({ listening: false })
    this.sceneLayer = new Konva.Layer({ listening: false })
    this.hitLayer = new Konva.Layer()
    this.overlayLayer = new Konva.Layer({ listening: false })
    
    this.stage.add(this.backgroundLayer)
    this.stage.add(this.sceneLayer)
    this.stage.add(this.hitLayer)
    this.stage.add(this.overlayLayer)
    
    this.stage.on("wheel", (event) => this.handleWheel(event))
    this.stage.on("touchmove", (event) => this.handleTouchMove(event))
    this.stage.on("touchend", () => this.handleTouchEnd())
    this.stage.on("dragstart", () => this.handleDragStart())
    this.stage.on("dragend", () => this.handleDragEnd())
    
    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(true)
    }
    
    window.addEventListener("resize", this.handleResize)
  }
  
  startTicking() {
    this.renderTick = setInterval(() => this.updateCountdowns(), 1000)
  }
  
  scheduleRender(resetView = false) {
    if (this.renderFrame) return
    
    this.renderFrame = requestAnimationFrame(() => {
      this.renderFrame = null
      this.renderScene(resetView)
    })
  }
  
  renderScene(resetView) {
    this.backgroundLayer.destroyChildren()
    this.sceneLayer.destroyChildren()
    this.hitLayer.destroyChildren()
    this.overlayLayer.destroyChildren()
    this.timerNodes.clear()
    
    const width = this.state.width || 1920
    const height = this.state.height || 1080
    
    this.renderBackdrop(width, height)
    this.renderSeats()
    this.renderGroups()
    this.renderTeamLabels()
    this.updateCountdowns()
    
    if (resetView) {
      this.fitToStage(true)
    } else {
      this.stage.batchDraw()
    }
  }
  
  renderBackdrop(width, height) {
    const theme = this.theme
    const backdrop = new Konva.Rect({
      x: 0,
      y: 0,
      width,
      height,
      fillLinearGradientStartPoint: { x: 0, y: 0 },
      fillLinearGradientEndPoint: { x: width, y: height },
      fillLinearGradientColorStops: [0, theme.backgroundGradientStart, 1, theme.backgroundGradientEnd],
      stroke: theme.borderColor,
      strokeWidth: 2
    })
    
    this.backgroundLayer.add(backdrop)
    
    const gridSize = 40
    const gridLines = new Konva.Shape({
      sceneFunc: (context) => {
        context.strokeStyle = theme.gridColor
        context.lineWidth = 0.5
        
        for (let x = 0; x <= width; x += gridSize) {
          context.beginPath()
          context.moveTo(x, 0)
          context.lineTo(x, height)
          context.stroke()
        }
        
        for (let y = 0; y <= height; y += gridSize) {
          context.beginPath()
          context.moveTo(0, y)
          context.lineTo(width, y)
          context.stroke()
        }
      },
      listening: false
    })
    
    this.backgroundLayer.add(gridLines)
    
    if (this.state.background_kind && this.state.background_kind !== "none" && this.state.background_value) {
      this.renderBackgroundImage(width, height)
    }
  }
  
  renderBackgroundImage(width, height) {
    const image = new window.Image()
    image.onload = () => {
      this.backgroundLayer.add(new Konva.Image({
        image,
        x: 0,
        y: 0,
        width,
        height,
        opacity: 0.12,
        listening: false
      }))
      this.backgroundLayer.batchDraw()
    }
    image.src = this.state.background_value
  }
  
  renderSeats() {
    const scale = 1
    const theme = this.theme
    const statusColors = this.statusColors
    
    ;(this.state.seats || []).forEach((seat) => {
      const palette = statusColors[seat.status] || statusColors.available
      const seatGroup = new Konva.Group({
        x: seat.x,
        y: seat.y,
        rotation: seat.rotation || 0,
        listening: false
      })
      
      seatGroup.setAttr("nodeType", "seat")
      seatGroup.setAttr("seatSlotId", seat.seat_slot_id)
      
      renderSeatShape(seatGroup, seat, palette, scale, theme, this.showKeyboard)
      
      seatGroup.add(new Konva.Text({
        x: -SEAT_WIDTH * 0.4,
        y: SEAT_HEIGHT * 0.12,
        width: SEAT_WIDTH * 0.8,
        align: "center",
        text: seat.label,
        fontSize: 11,
        fontStyle: "600",
        fontFamily: theme.fontFamily,
        fill: palette.text,
        perfectDrawEnabled: false,
        listening: false
      }))
      
      const timerNode = new Konva.Text({
        x: -SEAT_WIDTH * 0.35,
        y: -SEAT_HEIGHT * 0.38,
        width: SEAT_WIDTH * 0.7,
        align: "center",
        text: "",
        fontSize: 8,
        fontStyle: "bold",
        fontFamily: theme.fontFamily,
        fill: palette.accent,
        perfectDrawEnabled: false,
        listening: false,
        visible: false
      })
      
      if (seat.reservation_end_date) {
        this.timerNodes.set(seat.seat_slot_id, {
          node: timerNode,
          reservationEndDate: seat.reservation_end_date
        })
      }
      
      seatGroup.add(timerNode)
      
      this.sceneLayer.add(seatGroup)
      
      const hitTarget = new Konva.Rect({
        x: seat.x - SEAT_WIDTH * 0.6,
        y: seat.y - SEAT_HEIGHT * 0.6,
        width: SEAT_WIDTH * 1.2,
        height: SEAT_HEIGHT * 1.3,
        cornerRadius: 8,
        fill: "rgba(0,0,0,0.01)",
        strokeWidth: 0,
        perfectDrawEnabled: false
      })
      
      hitTarget.on("click tap", () => this.handleSeatClick(seat))
      this.hitLayer.add(hitTarget)
    })
  }
  
  renderGroups() {
    const theme = this.theme
    
    ;(this.state.groups || []).forEach((group) => {
      const memberSeats = (group.seat_slot_ids || [])
        .map((seatId) => (this.state.seats || []).find((seat) => seat.seat_slot_id === seatId))
        .filter(Boolean)
      
      if (memberSeats.length === 0) return
      
      const bounds = groupBounds(memberSeats)
      const color = group.color || "#22c55e"
      
      this.sceneLayer.add(new Konva.Rect({
        x: bounds.x - 12,
        y: bounds.y - 16,
        width: bounds.width + 24,
        height: bounds.height + 32,
        stroke: color,
        strokeWidth: 2,
        dash: [8, 6],
        cornerRadius: 12,
        fill: this.transparentColor(color, 0.08),
        perfectDrawEnabled: false,
        listening: false
      }))
      
      const hasTeamAssignment = (this.state.team_assignments || []).some(
        (assignment) => assignment.group_id === group.id
      )
      
      if (!hasTeamAssignment && group.name) {
        const text = new Konva.Text({
          text: group.name,
          fontFamily: theme.fontFamily,
          fontSize: 10,
          fontStyle: "600",
          fill: theme.textPrimary,
          listening: false
        })
        
        const labelWidth = text.width() + 16
        const labelHeight = 20
        const labelGroup = new Konva.Group({
          x: bounds.x + bounds.width / 2 - labelWidth / 2,
          y: bounds.y + bounds.height / 2 - labelHeight / 2,
          listening: false
        })
        
        labelGroup.add(new Konva.Rect({
          x: 0,
          y: 0,
          width: labelWidth,
          height: labelHeight,
          cornerRadius: 10,
          fill: this.transparentColor(color, 0.9),
          stroke: this.transparentColor("#ffffff", 0.2),
          strokeWidth: 1,
          perfectDrawEnabled: false
        }))
        
        text.position({ x: 8, y: 5 })
        labelGroup.add(text)
        this.sceneLayer.add(labelGroup)
      }
    })
  }
  
  renderTeamLabels() {
    const theme = this.theme
    
    ;(this.state.team_assignments || []).forEach((assignment) => {
      const group = (this.state.groups || []).find((entry) => entry.id === assignment.group_id)
      const memberSeats = group
        ? (group.seat_slot_ids || [])
            .map((seatId) => (this.state.seats || []).find((seat) => seat.seat_slot_id === seatId))
            .filter(Boolean)
        : []
      
      const bounds = memberSeats.length > 0 ? groupBounds(memberSeats) : null
      const x = bounds ? bounds.x + bounds.width / 2 : (assignment.label_x || 0)
      const y = bounds ? bounds.y + bounds.height / 2 - 12 : (assignment.label_y || 0)
      
      const text = new Konva.Text({
        text: `${assignment.team_name} · ${assignment.tournament_name}`,
        fontFamily: theme.fontFamily,
        fontSize: 11,
        fontStyle: "600",
        fill: theme.textPrimary,
        perfectDrawEnabled: false,
        listening: false
      })
      
      const width = text.width() + 20
      const height = 22
      const labelGroup = new Konva.Group({
        x: x - width / 2,
        y: y - height / 2,
        listening: false
      })
      
      labelGroup.add(new Konva.Rect({
        x: 0,
        y: 0,
        width,
        height,
        cornerRadius: 10,
        fill: this.transparentColor(assignment.color || "#06b6d4", 0.92),
        stroke: this.transparentColor("#ffffff", 0.2),
        strokeWidth: 1,
        shadowColor: "rgba(0, 0, 0, 0.4)",
        shadowBlur: 12,
        shadowOffset: { x: 0, y: 4 },
        shadowOpacity: 0.8,
        perfectDrawEnabled: false
      }))
      
      text.position({ x: 10, y: 6 })
      labelGroup.add(text)
      
      this.overlayLayer.add(labelGroup)
    })
  }
  
  handleSeatClick(seat) {
    this.hook.pushEvent("seat_selected", {
      seat_slot_id: seat.seat_slot_id,
      label: seat.label,
      status: seat.status
    })
  }
  
  updateCountdowns() {
    if (!this.timerNodes.size) return
    
    this.timerNodes.forEach(({ node, reservationEndDate }) => {
      const timer = countdownLabel(reservationEndDate)
      
      if (timer) {
        node.text(timer)
        node.show()
      } else {
        node.text("")
        node.hide()
      }
    })
    
    this.sceneLayer.batchDraw()
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
  
  handleDragStart() {
    this.hitLayer.listening(false)
  }
  
  handleDragEnd() {
    this.hitLayer.listening(true)
    this.stage.batchDraw()
  }
  
  transparentColor(hexColor, alpha) {
    const sanitized = (hexColor || "#22c55e").replace("#", "")
    const value = sanitized.length === 3 ? sanitized.split("").map((part) => `${part}${part}`).join("") : sanitized
    const red = parseInt(value.slice(0, 2), 16)
    const green = parseInt(value.slice(2, 4), 16)
    const blue = parseInt(value.slice(4, 6), 16)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
  }
}