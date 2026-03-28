import Konva from "konva"
import {
  SeatMapBase,
  STATUS_COLORS,
  THEME,
  clamp,
  groupBounds
} from "./seat_map_base"

const SEAT_WIDTH = 64
const SEAT_HEIGHT = 64

function renderSeatShapeSimple(seatGroup, seat, palette, scale, showKeyboard = true) {
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
    shadowBlur: 16,
    shadowOpacity: 0.7,
    perfectDrawEnabled: false
  }))
  
  seatGroup.add(new Konva.Rect({
    x: -w * 0.38,
    y: -h * 0.5,
    width: w * 0.76,
    height: h * 0.4,
    cornerRadius: 3,
    fill: "rgba(96, 165, 250, 0.15)",
    stroke: "rgba(96, 165, 250, 0.3)",
    strokeWidth: 1,
    perfectDrawEnabled: false
  }))
  
  seatGroup.add(new Konva.Circle({
    x: w * 0.32,
    y: -h * 0.05,
    radius: 4,
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
      fill: "rgba(139, 148, 158, 0.12)",
      stroke: "rgba(139, 148, 158, 0.25)",
      strokeWidth: 1,
      perfectDrawEnabled: false
    }))
  }
}

export default class SeatMapKiosk extends SeatMapBase {
  constructor(hook, options = {}) {
    super(hook, options)
    this.showKeyboard = options.showKeyboard !== false
    this.renderFrame = null
  }
  
  mount() {
    this.buildStage()
    this.renderScene(true)
  }
  
  buildStage() {
    this.stage = new Konva.Stage({
      container: this.stageContainer,
      width: this.stageContainer.clientWidth,
      height: this.stageContainer.clientHeight,
      draggable: false
    })
    
    this.backgroundLayer = new Konva.Layer({ listening: false })
    this.sceneLayer = new Konva.Layer({ listening: false })
    this.overlayLayer = new Konva.Layer({ listening: false })
    
    this.stage.add(this.backgroundLayer)
    this.stage.add(this.sceneLayer)
    this.stage.add(this.overlayLayer)
    
    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(true)
    }
    
    window.addEventListener("resize", this.handleResize)
  }
  
  destroy() {
    window.removeEventListener("resize", this.handleResize)
    if (this.renderFrame) window.cancelAnimationFrame(this.renderFrame)
    if (this.stage) this.stage.destroy()
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
    this.overlayLayer.destroyChildren()
    
    const width = this.state.width || 1920
    const height = this.state.height || 1080
    
    this.renderBackdrop(width, height)
    this.renderSeats()
    this.renderGroups()
    this.renderTeamLabels()
    
    if (resetView) {
      this.fitToStage(true)
    } else {
      this.stage.batchDraw()
    }
  }
  
  renderBackdrop(width, height) {
    const backdrop = new Konva.Rect({
      x: 0,
      y: 0,
      width,
      height,
      fillLinearGradientStartPoint: { x: 0, y: 0 },
      fillLinearGradientEndPoint: { x: width, y: height },
      fillLinearGradientColorStops: [0, THEME.backgroundGradientStart, 1, THEME.backgroundGradientEnd],
      stroke: THEME.borderColor,
      strokeWidth: 2
    })
    
    this.backgroundLayer.add(backdrop)
    
    const gridSize = 40
    const gridLines = new Konva.Shape({
      sceneFunc: (context) => {
        context.strokeStyle = THEME.gridColor
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
      },listening: false
    })
    
    this.backgroundLayer.add(gridLines)
    
    if (this.state.background_kind && this.state.background_kind !== "none" && this.state.background_value) {
      const image = new window.Image()
      image.onload = () => {
        this.backgroundLayer.add(new Konva.Image({
          image,
          x: 0,
          y: 0,
          width,
          height,
          opacity: 0.08,
          listening: false
        }))
        this.backgroundLayer.batchDraw()
      }
      image.src = this.state.background_value
    }
  }
  
  renderSeats() {
    const scale = 1.1
    
    ;(this.state.seats || []).forEach((seat) => {
      const palette = STATUS_COLORS[seat.status] || STATUS_COLORS.available
      const seatGroup = new Konva.Group({
        x: seat.x,
        y: seat.y,
        rotation: seat.rotation || 0,
        listening: false
      })
      
      renderSeatShapeSimple(seatGroup, seat, palette, scale, this.showKeyboard)
      
      seatGroup.add(new Konva.Text({
        x: -SEAT_WIDTH * 0.4,
        y: SEAT_HEIGHT * 0.14,
        width: SEAT_WIDTH * 0.8,
        align: "center",
        text: seat.label,
        fontSize: 12,
        fontStyle: "600",
        fontFamily: THEME.fontFamily,
        fill: palette.text,
        perfectDrawEnabled: false
      }))
      
      this.sceneLayer.add(seatGroup)
    })
  }
  
  renderGroups() {
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
        perfectDrawEnabled: false
      }))
      
      const hasTeamAssignment = (this.state.team_assignments || []).some(
        (assignment) => assignment.group_id === group.id
      )
      
      if (!hasTeamAssignment && group.name) {
        const text = new Konva.Text({
          text: group.name,
          fontFamily: THEME.fontFamily,
          fontSize: 10,
          fontStyle: "600",
          fill: THEME.textPrimary,
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
        fontFamily: THEME.fontFamily,
        fontSize: 12,
        fontStyle: "600",
        fill: THEME.textPrimary,
        perfectDrawEnabled: false,
        listening: false
      })
      
      const width = text.width() + 20
      const height = 24
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
        cornerRadius: 12,
        fill: this.transparentColor(assignment.color || "#06b6d4", 0.92),
        stroke: this.transparentColor("#ffffff", 0.2),
        strokeWidth: 1,
        shadowColor: "rgba(0, 0, 0, 0.5)",
        shadowBlur: 16,
        shadowOffset: { x: 0, y: 6 },
        shadowOpacity: 0.8,
        perfectDrawEnabled: false
      }))
      
      text.position({ x: 10, y: 7 })
      labelGroup.add(text)
      
      this.overlayLayer.add(labelGroup)
    })
  }
  
  fitToStage(resetPosition) {
    const padding = 40
    const width = this.state.width || 1920
    const height = this.state.height || 1080
    const scale = Math.min(
      (this.stage.width() - padding) / width,
      (this.stage.height() - padding) / height,
      1.2
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
  
  transparentColor(hexColor, alpha) {
    const sanitized = (hexColor || "#22c55e").replace("#", "")
    const value = sanitized.length === 3 ? sanitized.split("").map((part) => `${part}${part}`).join("") : sanitized
    const red = parseInt(value.slice(0, 2), 16)
    const green = parseInt(value.slice(2, 4), 16)
    const blue = parseInt(value.slice(4, 6), 16)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
  }
}