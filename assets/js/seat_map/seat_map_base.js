import Konva from "konva"
import { getThemeColors, getStatusColors } from "./seat_map_theme"
import { onThemeChange } from "../theme-core.js"

Konva.hitOnDragEnabled = true
Konva.capturePointerEventsEnabled = true
// Without a drag threshold any pixel of wobble starts a drag, and Konva then
// swallows the click event, so clicking a node would never select it.
Konva.dragDistance = 4

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
  const widths = seats.map(seat => seat.width)
  const heights = seats.map(seat => seat.height)
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
    this.stage = null
    this.renderFrame = null
    this._cachedTheme = null
    this._cachedStatusColors = null
    this._unsubscribeTheme = null
  }

  getContentBounds() {
    const seats = this.state.seats
    const objects = this.state.objects

    if (seats.length === 0 && objects.length === 0) {
      return { x: 0, y: 0, width: this.state.width, height: this.state.height }
    }

    let minX = Infinity, minY = Infinity
    let maxX = -Infinity, maxY = -Infinity

    for (const seat of seats) {
      const halfW = seat.width / 2
      const halfH = seat.height / 2
      minX = Math.min(minX, seat.x - halfW)
      maxX = Math.max(maxX, seat.x + halfW)
      minY = Math.min(minY, seat.y - halfH)
      maxY = Math.max(maxY, seat.y + halfH)
    }

    for (const obj of objects) {
      minX = Math.min(minX, obj.x)
      maxX = Math.max(maxX, obj.x + obj.width)
      minY = Math.min(minY, obj.y)
      maxY = Math.max(maxY, obj.y + obj.height)
    }

    return {
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY
    }
  }

  // Center content bounds in viewport (used when content fits)
  centerCanvas() {
    const scale = this.stage.scaleX()
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
    const scale = this.stage.scaleX()
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
    const oldScale = this.stage.scaleX()

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

  // Fit content to viewport with optional scale limits
  fitToStage(resetPosition, options = {}) {
    const {
      maxVisibleScale = 1.5,
      minScaleOverride,
      maxScaleOverride,
      updateDraggable = false,
      padding =60
    } = options

    const bounds = this.getContentBounds()
    const stageWidth = this.stage.width()
    const stageHeight = this.stage.height()

    if (bounds.width === 0 || bounds.height === 0) return

    const scale = Math.min(
      (stageWidth - padding) / bounds.width,
      (stageHeight - padding) / bounds.height,
      maxVisibleScale
    )
    const minScale = minScaleOverride ?? this.getMinScale()
    const maxScale = maxScaleOverride ?? this.getMaxScale()
    const clampedScale = clamp(scale, minScale, maxScale)

    if (resetPosition) {
      this.stage.scale({ x: clampedScale, y: clampedScale })
      const scaledWidth = bounds.width * clampedScale
      const scaledHeight = bounds.height * clampedScale
      this.stage.position({
        x: (stageWidth - scaledWidth) / 2 - bounds.x * clampedScale,
        y: (stageHeight - scaledHeight) / 2 - bounds.y * clampedScale
      })
    }

    if (updateDraggable) {
      this.stage.draggable(!this.canvasFitsInViewport())
    }

    this.stage.batchDraw()
  }

  // Handle wheel zoom with pointer-relative scaling
  handleWheel(event, options = {}) {
    const { updateDraggable = false, hitLayer = null } = options

    event.evt.preventDefault()

    if (hitLayer) hitLayer.listening(false)

    const oldScale = this.stage.scaleX()
    const pointer = this.stage.getPointerPosition()
    // Convert screen coordinates to canvas coordinates before zoom
    const canvasPoint = {
      x: (pointer.x - this.stage.x()) / oldScale,
      y: (pointer.y - this.stage.y()) / oldScale
    }

    const direction = event.evt.deltaY > 0 ? 1 : -1
    const nextScale = direction > 0 ? oldScale / SCALE_BY : oldScale * SCALE_BY
    const minScale = this.getMinScale()
    const maxScale = this.getMaxScale()
    const newScale = clamp(nextScale, minScale, maxScale)

    // Zoom relative to pointer - keep canvas point under cursor
    this.stage.scale({ x: newScale, y: newScale })
    this.stage.position({
      x: pointer.x - canvasPoint.x * newScale,
      y: pointer.y - canvasPoint.y * newScale
    })

    // When fully zoomed out the canvas fits: center it. Otherwise panning is
    // unconstrained - the user can recover with the reset-view button.
    if (this.canvasFitsInViewport()) {
      this.centerCanvas()
    }

    if (updateDraggable) {
      this.stage.draggable(!this.canvasFitsInViewport())
    }

    this.stage.batchDraw()

    if (hitLayer) {
      requestAnimationFrame(() => { hitLayer.listening(true) })
    }
  }

  // Handle touch pinch-zoom and pan
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
      const minScale = this.getMinScale()
      const maxScale = this.getMaxScale()
      const clampedScale = clamp(scale, minScale, maxScale)
      // Convert center point to canvas coordinates before zoom
      const pointTo = {
        x: (center.x - this.stage.x()) / this.stage.scaleX(),
        y: (center.y - this.stage.y()) / this.stage.scaleY()
      }

      this.stage.scale({ x: clampedScale, y: clampedScale })

      // Apply pan delta from touch movement
      const dx = center.x - this.lastTouchCenter.x
      const dy = center.y - this.lastTouchCenter.y

      this.stage.position({
        x: center.x - pointTo.x * clampedScale + dx,
        y: center.y - pointTo.y * clampedScale + dy
      })

      this.lastTouchCenter = center
      this.lastTouchDistance = distance
      this.stage.batchDraw()
    }
  }

  handleTouchEnd() {
    this.lastTouchCenter = null
    this.lastTouchDistance = 0
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
        // Setting scheduleRender(true) will reset the zoom level on theme change
        // and other things. Not necessary
        this.scheduleRender(false)
      }
    })
  }

  teardownThemeListener() {
    if (this._unsubscribeTheme) {
      this._unsubscribeTheme()
      this._unsubscribeTheme = null
    }
  }

  // Setup window resize handler to re-fit stage to container
  setupResizeHandler() {
    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(true)
    }
    window.addEventListener("resize", this.handleResize)
  }

  teardownResizeHandler() {
    if (this.handleResize) {
      window.removeEventListener("resize", this.handleResize)
      this.handleResize = null
    }
  }

  setPayload(payload) {
    this.state = clone(payload)
  }

  update(payload) {
    this.state = clone(payload)
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
    this.teardownResizeHandler()
    if (this.renderFrame) cancelAnimationFrame(this.renderFrame)
    if (this.stage) this.stage.destroy()
  }
}
