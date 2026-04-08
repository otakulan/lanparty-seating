import Konva from "konva"
import { getThemeColors, getStatusColors } from "./seat_map_theme"
import { onThemeChange } from "../theme-core.js"
import { renderGroupBounds, renderGroupLabel, renderTeamLabel } from "./seat_map_renderer"

Konva.hitOnDragEnabled = true
Konva.captureTouchEventsEnabled = true

export { getThemeColors, getStatusColors }

export const SCALE_BY = 1.08

export function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

export function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}

export function getDistance(pointA, pointB) {
  return Math.hypot(pointB.x - pointA.x, pointB.y - pointA.y)
}

export function getCenter(pointA, pointB) {
  return {
    x: (pointA.x + pointB.x) / 2,
    y: (pointA.y + pointB.y) / 2
  }
}

export function randomId(prefix) {
  return `${prefix}-${Math.random().toString(36).slice(2, 10)}`
}

export function parseInteger(value, fallback = 0) {
  if (Number.isInteger(value)) return value
  if (typeof value === "number") return Math.round(value)
  if (typeof value === "string") {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? Math.round(parsed) : fallback
  }
  return fallback
}

export function buildStage(container, width, height, draggable = true) {
  return new Konva.Stage({
    container,
    width,
    height,
    draggable
  })
}

export function createEditorLayers(stage) {
  const theme = getThemeColors()
  const backgroundLayer = new Konva.Layer({ listening: false })
  const objectLayer = new Konva.Layer()
  const groupLayer = new Konva.Layer({ listening: false })
  const seatLayer = new Konva.Layer()
  const overlayLayer = new Konva.Layer({ listening: false })
  
  const transformer = new Konva.Transformer({
    rotateEnabled: true,
    borderStroke: theme.accentCyan,
    anchorStroke: theme.accentCyan,
    anchorFill: theme.accentGreen,
    anchorSize: 8,
    anchorCornerRadius: 3,
    visible: false,
    ignoreStroke: true
  })
  
  objectLayer.add(transformer)
  
  stage.add(backgroundLayer)
  stage.add(groupLayer)
  stage.add(seatLayer)
  stage.add(objectLayer)
  stage.add(overlayLayer)
  
  return { backgroundLayer, objectLayer, groupLayer, seatLayer, overlayLayer, transformer }
}

export function groupBounds(seats) {
  if (!seats || seats.length === 0) return { x: 0, y: 0, width: 0, height: 0 }
  
  const xs = seats.map(seat => seat.x)
  const ys = seats.map(seat => seat.y)
  const widths = seats.map(seat => seat.width || 64)
  const heights = seats.map(seat => seat.height || 64)
  const minX = Math.min(...xs.map((x, i) => x - widths[i] / 2))
  const maxX = Math.max(...xs.map((x, i) => x + widths[i] / 2))
  const minY = Math.min(...ys.map((y, i) => y - heights[i] / 2))
  const maxY = Math.max(...ys.map((y, i) => y + heights[i] / 2))
  
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
}

export function getCorner(pivotX, pivotY, diffX, diffY, angle) {
  const distance = Math.sqrt(diffX * diffX + diffY * diffY)
  angle += Math.atan2(diffY, diffX)
  const x = pivotX + distance * Math.cos(angle)
  const y = pivotY + distance * Math.sin(angle)
  return { x, y }
}

export function getClientRect(rotatedBox) {
  const { x, y, width, height } = rotatedBox
  const rad = rotatedBox.rotation || 0

  const p1 = getCorner(x, y, 0, 0, rad)
  const p2 = getCorner(x, y, width, 0, rad)
  const p3 = getCorner(x, y, width, height, rad)
  const p4 = getCorner(x, y, 0, height, rad)

  const minX = Math.min(p1.x, p2.x, p3.x, p4.x)
  const minY = Math.min(p1.y, p2.y, p3.y, p4.y)
  const maxX = Math.max(p1.x, p2.x, p3.x, p4.x)
  const maxY = Math.max(p1.y, p2.y, p3.y, p4.y)

  return {
    x: minX,
    y: minY,
    width: maxX - minX,
    height: maxY - minY,
  }
}

export function getTotalBox(boxes) {
  let minX = Infinity
  let minY = Infinity
  let maxX = -Infinity
  let maxY = -Infinity

  boxes.forEach(box => {
    minX = Math.min(minX, box.x)
    minY = Math.min(minY, box.y)
    maxX = Math.max(maxX, box.x + box.width)
    maxY = Math.max(maxY, box.y + box.height)
  })
  
  return {
    x: minX,
    y: minY,
    width: maxX - minX,
    height: maxY - minY,
  }
}

export function rectsOverlap(r1, r2) {
  return !(r1.x + r1.width <= r2.x || r2.x + r2.width <= r1.x ||
           r1.y + r1.height <= r2.y || r2.y + r2.height <= r1.y)
}

export class SeatMapBase {
  constructor(hook, options = {}) {
    this.hook = hook
    this.el = hook.el
    this.mode = options.mode || "view"
    this.stageContainer = this.el.querySelector("[data-seat-map-stage]")
    this.state = {}
    this.renderFrame = null
    this._cachedTheme = null
    this._cachedStatusColors = null
    this._unsubscribeTheme = null
  }
  
  getContentBounds() {
    const seats = this.state.seats || []
    const objects = this.state.objects || []
    const defaultWidth = this.state.width || 1920
    const defaultHeight = this.state.height || 1080
    
    if (seats.length === 0 && objects.length === 0) {
      return { x: 0, y: 0, width: defaultWidth, height: defaultHeight }
    }
    
    let minX = Infinity, minY = Infinity
    let maxX = -Infinity, maxY = -Infinity
    
    for (const seat of seats) {
      const halfW = (seat.width || 64) / 2
      const halfH = (seat.height || 64) / 2
      minX = Math.min(minX, seat.x - halfW)
      maxX = Math.max(maxX, seat.x + halfW)
      minY = Math.min(minY, seat.y - halfH)
      maxY = Math.max(maxY, seat.y + halfH)
    }
    
    for (const obj of objects) {
      minX = Math.min(minX, obj.x)
      maxX = Math.max(maxX, obj.x + (obj.width || 100))
      minY = Math.min(minY, obj.y)
      maxY = Math.max(maxY, obj.y + (obj.height || 60))
    }
    
    return {
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY
    }
  }
  
  // Constrain panning to keep at least one seat visible within center of viewport.
  // When content fits: center it and disable panning.
  // When content larger: allow pan within 40%-60% zone (center 20%).
  constrainStageDrag() {
    const scale = this.stage.scaleX() || 1
    const bounds = this.getContentBounds()
    const stageWidth = this.stage.width()
    const stageHeight = this.stage.height()
    
    if (bounds.width === 0 || bounds.height === 0) return
    
    const scaledWidth = bounds.width * scale
    const scaledHeight = bounds.height * scale
    const margin = 40
    
    const centerXMin = 0.4 * stageWidth
    const centerXMax = 0.6 * stageWidth
    const centerYMin = 0.4 * stageHeight
    const centerYMax = 0.6 * stageHeight
    
    let newX = this.stage.x()
    let newY = this.stage.y()
    
    if (scaledWidth <= stageWidth - margin * 2) {
      // Content fits: center it
      newX = (stageWidth - scaledWidth) / 2 - bounds.x * scale
    } else {
      // Constrain to keep last seat within center 40%-60% zone
      const minX = centerXMin - (bounds.x + bounds.width) * scale
      const maxX = centerXMax - bounds.x * scale
      if (minX <= maxX) newX = clamp(newX, minX, maxX)
    }
    
    if (scaledHeight <= stageHeight - margin * 2) {
      newY = (stageHeight - scaledHeight) / 2 - bounds.y * scale
    } else {
      const minY = centerYMin - (bounds.y + bounds.height) * scale
      const maxY = centerYMax - bounds.y * scale
      if (minY <= maxY) newY = clamp(newY, minY, maxY)
    }
    
    this.stage.position({ x: newX, y: newY })
  }
  
  // Center content bounds in viewport (used when content fits)
  centerCanvas() {
    const scale = this.stage.scaleX() || 1
    const bounds = this.getContentBounds()
    const stageWidth = this.stage.width()
    const stageHeight = this.stage.height()
    
    const scaledWidth = bounds.width * scale
    const scaledHeight = bounds.height * scale
    
    this.stage.position({
      x: (stageWidth - scaledWidth) / 2 - bounds.x * scale,
      y: (stageHeight - scaledHeight) / 2 - bounds.y * scale
    })
  }
  
  // Check if content fits entirely within viewport (with margin)
  canvasFitsInViewport() {
    const scale = this.stage.scaleX() || 1
    const bounds = this.getContentBounds()
    const stageWidth = this.stage.width()
    const stageHeight = this.stage.height()
    const margin = 40
    
    const scaledWidth = bounds.width * scale
    const scaledHeight = bounds.height * scale
    
    return scaledWidth <= stageWidth - margin * 2 && scaledHeight <= stageHeight - margin * 2
  }
  
  // Scale stage relative to center point (used by zoom buttons)
  scaleStage(nextScale) {
    const minScale = this.getMinScale()
    const maxScale = this.getMaxScale()
    const clampedScale = clamp(nextScale, minScale, maxScale)
    const center = { x: this.stage.width() / 2, y: this.stage.height() / 2 }
    const oldScale = this.stage.scaleX() || 1
    
    // Convert center point to canvas coordinates before zoom
    const pointTo = {
      x: (center.x - this.stage.x()) / oldScale,
      y: (center.y - this.stage.y()) / oldScale
    }
    
    this.stage.scale({ x: clampedScale, y: clampedScale })
    this.stage.position({
      x: center.x - pointTo.x * clampedScale,
      y: center.y - pointTo.y * clampedScale
    })
    
    this.constrainStageDrag()
    this.stage.batchDraw()
  }
  
  // Calculate minimum scale where content fits with 80px padding (40px each side)
  getMinScale() {
    const padding = 40
    const bounds = this.getContentBounds()
    const stageWidth = this.stage.width()
    const stageHeight = this.stage.height()
    
    if (bounds.width === 0 || bounds.height === 0) return 1
    
    return Math.min(
      (stageWidth - padding * 2) / bounds.width,
      (stageHeight - padding * 2) / bounds.height,
      1
    )
  }
  
  // Maximum zoom level - subclasses must implement
  getMaxScale() {
    throw new Error('getMaxScale must be implemented by subclass')
  }
  
  // Render group bounding boxes and labels (shared by all views)
  renderGroups() {
    const theme = this.theme
    const groups = this.state.groups || []
    const seats = this.state.seats || []
    const teamAssignments = this.state.team_assignments || []
    const groupLayer = this.getGroupLayer()
    
    for (const group of groups) {
      renderGroupBounds(groupLayer, group, seats, theme)
      renderGroupLabel(groupLayer, group, seats, teamAssignments, theme)
    }
  }
  
  // Render tournament team assignments (shared by all views)
  renderTeamLabels() {
    const theme = this.theme
    const groups = this.state.groups || []
    const seats = this.state.seats || []
    
    for (const assignment of this.state.team_assignments || []) {
      renderTeamLabel(this.overlayLayer, assignment, groups, seats, theme)
    }
  }
  
  // Subclasses must implement to return their group layer
  getGroupLayer() {
    throw new Error('getGroupLayer must be implemented by subclass')
  }
  
  get theme() {
    if (!this._cachedTheme) {
      this._cachedTheme = getThemeColors()
    }
    return this._cachedTheme
  }
  
  get statusColors() {
    if (!this._cachedStatusColors) {
      this._cachedStatusColors = getStatusColors()
    }
    return this._cachedStatusColors
  }
  
  clearThemeCache() {
    this._cachedTheme = null
    this._cachedStatusColors = null
  }
  
  setupThemeListener() {
    this._unsubscribeTheme = onThemeChange(() => {
      this.clearThemeCache()
      if (this.stage) {
        this.scheduleRender(true)
      }
    })
  }
  
  teardownThemeListener() {
    if (this._unsubscribeTheme) {
      this._unsubscribeTheme()
      this._unsubscribeTheme = null
    }
  }
  
  setPayload(payload) {
    this.state = clone(payload || {})
  }
  
  update(payload) {
    this.state = clone(payload || {})
  }
  
  scheduleRender(resetView = false) {
    if (this.renderFrame) return
    this.renderFrame = requestAnimationFrame(() => {
      this.renderFrame = null
      this.renderScene(resetView)
    })
  }
  
  destroy() {
    this.teardownThemeListener()
    if (this.renderFrame) cancelAnimationFrame(this.renderFrame)
    if (this.stage) this.stage.destroy()
  }
}