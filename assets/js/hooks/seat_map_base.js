import Konva from "konva"

Konva.hitOnDragEnabled = false
Konva.captureTouchEventsEnabled = true
Konva.pixelRatio = 1

export const STATUS_COLORS = {
  available: { 
    fill: "#0d1117", 
    fillSecondary: "#161b22",
    stroke: "#22c55e", 
    text: "#22c55e", 
    glow: "rgba(34, 197, 94, 0.35)",
    accent: "#4ade80"
  },
  occupied: { 
    fill: "#0d1117", 
    fillSecondary: "#161b22",
    stroke: "#f59e0b", 
    text: "#f59e0b", 
    glow: "rgba(245, 158, 11, 0.35)",
    accent: "#fbbf24"
  },
  reserved: { 
    fill: "#0d1117", 
    fillSecondary: "#161b22",
    stroke: "#6b7280", 
    text: "#9ca3af", 
    glow: "rgba(107, 114, 128, 0.3)",
    accent: "#9ca3af"
  },
  unavailable: { 
    fill: "#0d1117", 
    fillSecondary: "#161b22",
    stroke: "#ef4444", 
    text: "#ef4444", 
    glow: "rgba(239, 68, 68, 0.35)",
    accent: "#f87171"
  },
  tournament: { 
    fill: "#0d1117", 
    fillSecondary: "#161b22",
    stroke: "#06b6d4", 
    text: "#06b6d4", 
    glow: "rgba(6, 182, 212, 0.35)",
    accent: "#22d3ee"
  }
}

export const THEME = {
  background: "#0d1117",
  backgroundGradientStart: "#0d1117",
  backgroundGradientEnd: "#161b22",
  borderColor: "#30363d",
  gridColor: "rgba(48, 54, 61, 0.4)",
  panelBg: "rgba(22, 27, 34, 0.95)",
  panelBorder: "#30363d",
  textPrimary: "#e6edf3",
  textSecondary: "#8b949e",
  textMuted: "#6e7681",
  accentGreen: "#22c55e",
  accentCyan: "#06b6d4",
  accentAmber: "#f59e0b",
  fontFamily: "'JetBrains Mono', 'SF Mono', ui-monospace, Menlo, monospace",
  displayFont: "'JetBrains Mono', 'SF Pro Display', -apple-system, sans-serif"
}

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
    x: (pointA.x + pointB.x) /2,
    y: (pointA.y + pointB.y) /2
  }
}

export function countdownLabel(isoValue) {
  if (!isoValue) return null
  const endDate = new Date(isoValue)
  const diff = Math.max(0, endDate.getTime() - Date.now())
  const minutes = Math.floor(diff / 60000)
  const seconds = Math.floor((diff % 60000) / 1000)
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
}

export function randomId(prefix) {
  return `${prefix}-${Math.random().toString(36).slice(2, 10)}`
}

export function parseInteger(value, fallback = 0) {
  if (Number.isInteger(value)) return value
  if (typeof value === "number") return Math.round(value)
  if (typeof value === "string") {
    const parsed = Number(value)
    return Number.isFinite(parsed)? Math.round(parsed) : fallback
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

export function createBaseLayers(stage) {
  const backgroundLayer = new Konva.Layer({ listening: false })
  const sceneLayer = new Konva.Layer({ listening: false })
  const overlayLayer = new Konva.Layer({ listening: false })
  
  stage.add(backgroundLayer)
  stage.add(sceneLayer)
  stage.add(overlayLayer)
  
  return { backgroundLayer, sceneLayer, overlayLayer }
}

export function createEditorLayers(stage) {
  const backgroundLayer = new Konva.Layer({ listening: false })
  const objectLayer = new Konva.Layer()
  const groupLayer = new Konva.Layer({ listening: false })
  const seatLayer = new Konva.Layer()
  const overlayLayer = new Konva.Layer({ listening: false })
  
  const transformer = new Konva.Transformer({
    rotateEnabled: true,
    borderStroke: THEME.accentCyan,
    anchorStroke: THEME.accentCyan,
    anchorFill: THEME.accentGreen,
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

export function renderDarkBackdrop(layer, width, height) {
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
  
  layer.add(backdrop)
  
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
    },
    listening: false
  })
  
  layer.add(gridLines)
}

export function renderBackgroundImage(layer, src, width, height) {
  if (!src) return
  
  const image = new window.Image()
  image.onload = () => {
    layer.add(new Konva.Image({
      image,
      x: 0,
      y: 0,
      width,
      height,
      opacity: 0.15,
      listening: false
    }))
    layer.batchDraw()
  }
  image.src = src
}

export function groupBounds(seats) {
  if (!seats || seats.length === 0) return { x: 0, y: 0, width: 0, height: 0 }
  
  const xs = seats.map((seat) => seat.x)
  const ys = seats.map((seat) => seat.y)
  const widths = seats.map((seat) => seat.width || 64)
  const heights = seats.map((seat) => seat.height || 64)
  const minX = Math.min(...xs.map((x, index) => x - widths[index] / 2))
  const maxX = Math.max(...xs.map((x, index) => x + widths[index] / 2))
  const minY = Math.min(...ys.map((y, index) => y - heights[index] / 2))
  const maxY = Math.max(...ys.map((y, index) => y + heights[index] / 2))
  
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
}

export class SeatMapBase {
  constructor(hook, options = {}) {
    this.hook = hook
    this.el = hook.el
    this.mode = options.mode || "view"
    this.stageContainer = this.el.querySelector("[data-seat-map-stage]")
    this.state = this.parsePayload()
  }
  
  parsePayload() {
    return clone(JSON.parse(this.el.dataset.seatMap || "{}"))
  }
  
  update() {
    this.state = this.parsePayload()
  }
  
  destroy() {
    if (this.stage) this.stage.destroy()
  }
}