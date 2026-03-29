import Konva from "konva"
import { getThemeColors, getStatusColors } from "./seat_map_theme"

Konva.hitOnDragEnabled = false
Konva.captureTouchEventsEnabled = true
Konva.pixelRatio = 1

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

export class SeatMapBase {
  constructor(hook, options = {}) {
    this.hook = hook
    this.el = hook.el
    this.mode = options.mode || "view"
    this.stageContainer = this.el.querySelector("[data-seat-map-stage]")
    this.state = this.parsePayload()
    this.renderFrame = null
    this._cachedTheme = null
    this._cachedStatusColors = null
    this._themeChangeListener = null
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
    if (typeof window === 'undefined' || !window.matchMedia) return
    
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    this._themeChangeListener = () => {
      this.clearThemeCache()
      if (this.stage) {
        this.scheduleRender(true)
      }
    }
    mediaQuery.addEventListener('change', this._themeChangeListener)
  }
  
  teardownThemeListener() {
    if (this._themeChangeListener && typeof window !== 'undefined' && window.matchMedia) {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      mediaQuery.removeEventListener('change', this._themeChangeListener)
    }
  }
  
  parsePayload() {
    return clone(JSON.parse(this.el.dataset.seatMap || "{}"))
  }
  
  update() {
    this.state = this.parsePayload()
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