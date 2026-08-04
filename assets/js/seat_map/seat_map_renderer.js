import Konva from "konva"
import { getThemeColors, getStatusColors } from "./seat_map_theme"

export const SEAT_WIDTH = 64
export const SEAT_HEIGHT = 64
export const SEAT_SCALE = 1
export const SHADOW_BLUR = 12
export const SHADOW_OPACITY = 0.6
export const ACCENT_RADIUS = 3

const STATUS_ICON_SIZE = 26
const LOCK_BADGE_SIZE = 14
const LOCK_BADGE_RADIUS = 10

const LOCK_ICON_PATH =
  "M5 11 H19 A2 2 0 0 1 21 13 V20 A2 2 0 0 1 19 22 H5 A2 2 0 0 1 3 20 V13 A2 2 0 0 1 5 11 Z M7 11 V7 A5 5 0 0 1 17 7 V11"

const STATUS_ICON_PATHS = {
  occupied: "M12 2 A10 10 0 1 0 12 22 A10 10 0 1 0 12 2 Z M12 6 L12 12 L16 14",
  unavailable:
    "M2.586 16.726 A2 2 0 0 1 2 15.312 V8.688 A2 2 0 0 1 2.586 7.274 L7.274 2.586 A2 2 0 0 1 8.688 2 H15.312 A2 2 0 0 1 16.726 2.586 L21.414 7.274 A2 2 0 0 1 22 8.688 V15.312 A2 2 0 0 1 21.414 16.726 L16.726 21.414 A2 2 0 0 1 15.312 22 H8.688 A2 2 0 0 1 7.274 21.414 Z M15 9 L9 15 M9 9 L15 15",
  tournament:
    "M10 14.66 V17 a1 1 0 0 1-1 1 2 2 0 0 0-2 2 v2 M14 14.66 V17 a1 1 0 0 0 1 1 2 2 0 0 1 2 2 v2 M17.916 10 H19.5 A2.5 2.5 0 0 0 22 7.5 V5 a1 1 0 0 0-1-1 h-3 M4 22 h16 M6 9 a6 6 0 0 0 12 0 V3 a1 1 0 0 0-1-1 H7 a1 1 0 0 0-1 1 z M6.084 10 H4.5 A2.5 2.5 0 0 1 2 7.5 V5 a1 1 0 0 1 1-1 h3",
  reserved:
    "M5 11 H19 A2 2 0 0 1 21 13 V20 A2 2 0 0 1 19 22 H5 A2 2 0 0 1 3 20 V13 A2 2 0 0 1 5 11 Z M7 11 V7 A5 5 0 0 1 17 7 V11"
}

export function createSeatGroup(seat, palette, theme, options = {}) {
  const { showKeyboard = true, cacheBody = true } = options

  const group = new Konva.Group({
    x: seat.x,
    y: seat.y,
    rotation: seat.rotation,
    listening: false
  })

  const bodyGroup = createSeatBodyGroup(palette, theme, { showKeyboard })
  if (cacheBody) {
    bodyGroup.cache()
  }
  group.add(bodyGroup)

  addSeatStatusIcon(group, seat, palette)

  group.setAttr("nodeType", "seat")
  group.setAttr("seatSlotId", seat.seat_slot_id)

  return group
}

export function createSeatBodyGroup(palette, theme, options = {}) {
  const { showKeyboard = true, isSelected = false, isLocked = false } = options

  // Listening must stay on: in the editor the seat group is interactive and the
  // body shapes need to be hittable. The viewer/kiosk seat group is itself
  // listening:false, so this value is ignored there.
  const bodyGroup = new Konva.Group({ listening: true })

  addSeatBody(bodyGroup, palette, theme, { isSelected, isLocked })
  addSeatMonitor(bodyGroup, theme)
  addSeatAccent(bodyGroup, palette)

  if (showKeyboard) {
    addSeatKeyboard(bodyGroup, theme)
  }

  return bodyGroup
}

function addSeatBody(group, palette, theme, options = {}) {
  const { isSelected = false, isLocked = false } = options
  const w = SEAT_WIDTH
  const h = SEAT_HEIGHT

  group.add(new Konva.Rect({
    x: -w / 2,
    y: -h * 0.6,
    width: w,
    height: h * 0.75,
    cornerRadius: 6,
    fillLinearGradientStartPoint: { x: 0, y: 0 },
    fillLinearGradientEndPoint: { x: w, y: h * 0.75 },
    fillLinearGradientColorStops: [0, palette.fillSecondary, 0.5, palette.fill, 1, palette.fill],
    stroke: isLocked ? theme.lockBadge : isSelected ? palette.accent : palette.stroke,
    strokeWidth: isSelected ? 3 : 2,
    dash: isLocked ? [6, 4] : undefined,
    shadowColor: palette.glow,
    shadowBlur: isSelected ? 20 : SHADOW_BLUR,
    shadowOpacity: isSelected ? 1 : SHADOW_OPACITY,
    perfectDrawEnabled: false,
    shadowForStrokeEnabled: false
  }))
}

function addSeatMonitor(group, theme) {
  const w = SEAT_WIDTH
  const h = SEAT_HEIGHT

  group.add(new Konva.Rect({
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
}

function addSeatAccent(group, palette) {
  const w = SEAT_WIDTH
  const h = SEAT_HEIGHT

  group.add(new Konva.Circle({
    x: w * 0.32,
    y: -h * 0.05,
    radius: ACCENT_RADIUS,
    fill: palette.accent,
    perfectDrawEnabled: false
  }))
}

function addSeatKeyboard(group, theme) {
  const w = SEAT_WIDTH
  const h = SEAT_HEIGHT

  group.add(new Konva.Rect({
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

export function addSeatStatusIcon(group, seat, palette) {
  const data = STATUS_ICON_PATHS[seat.status]
  if (!data) return

  const centerX = 0
  const centerY = -SEAT_HEIGHT * 0.6 + (SEAT_HEIGHT * 0.75) / 2

  group.add(new Konva.Path({
    x: centerX - STATUS_ICON_SIZE / 2,
    y: centerY - STATUS_ICON_SIZE / 2,
    scaleX: STATUS_ICON_SIZE / 24,
    scaleY: STATUS_ICON_SIZE / 24,
    data,
    stroke: palette.accent,
    strokeWidth: 2,
    lineCap: "round",
    lineJoin: "round",
    perfectDrawEnabled: false,
    listening: false
  }))
}

// Editor-only badge marking a node as locked (not movable / not resizable).
export function createLockBadge(theme, position = { x: 0, y: 0 }) {
  const badge = new Konva.Group({
    x: position.x,
    y: position.y,
    listening: false,
    name: "lock-badge"
  })

  badge.add(new Konva.Circle({
    radius: LOCK_BADGE_RADIUS,
    fill: theme.lockBadgeBg,
    stroke: theme.lockBadge,
    strokeWidth: 1.5,
    perfectDrawEnabled: false,
    shadowForStrokeEnabled: false
  }))

  badge.add(new Konva.Path({
    x: -LOCK_BADGE_SIZE / 2,
    y: -LOCK_BADGE_SIZE / 2,
    scaleX: LOCK_BADGE_SIZE / 24,
    scaleY: LOCK_BADGE_SIZE / 24,
    data: LOCK_ICON_PATH,
    stroke: theme.lockBadge,
    strokeWidth: 2.5,
    lineCap: "round",
    lineJoin: "round",
    perfectDrawEnabled: false
  }))

  return badge
}

export function addSeatLabel(group, seat, theme, _palette, options = {}) {
  const { listening = false } = options
  // Base content color instead of the status color: status is already carried by
  // the seat body/icon and colored text is hard to read on some themes.
  group.add(new Konva.Text({
    x: -SEAT_WIDTH * 0.45,
    // Vertically centered on the keyboard (y 0.22h..0.50h)
    //y: SEAT_HEIGHT * 0.24,
    // Centered on the monitor screen instead (y -0.50h..-0.10h):
    y: -SEAT_HEIGHT * 0.42,
    width: SEAT_WIDTH * 0.9,
    align: "center",
    text: seat.label,
    fontSize: 15,
    fontStyle: "600",
    fontFamily: theme.fontFamily,
    fill: theme.textPrimary,
    perfectDrawEnabled: false,
    listening
  }))
}

export function createTimerNode(theme, palette) {
  return new Konva.Text({
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
    visible: false,
    name: "timer-text"
  })
}

export function createHitTarget(seat, scale = 1) {
  return new Konva.Rect({
    x: seat.x - SEAT_WIDTH * 0.6 * scale,
    y: seat.y - SEAT_HEIGHT * 0.6 * scale,
    width: SEAT_WIDTH * 1.2 * scale,
    height: SEAT_HEIGHT * 1.3 * scale,
    cornerRadius: 8,
    fill: "rgba(0,0,0,0.01)",
    strokeWidth: 0,
    perfectDrawEnabled: false
  })
}

export function calculateBounds(seats) {
  if (!seats || seats.length === 0) {
    return { x: 0, y: 0, width: 0, height: 0 }
  }

  const xs = seats.map(s => s.x)
  const ys = seats.map(s => s.y)
  const widths = seats.map(s => s.width)
  const heights = seats.map(s => s.height)

  const minX = Math.min(...xs.map((x, i) => x - widths[i] / 2))
  const maxX = Math.max(...xs.map((x, i) => x + widths[i] / 2))
  const minY = Math.min(...ys.map((y, i) => y - heights[i] / 2))
  const maxY = Math.max(...ys.map((y, i) => y + heights[i] / 2))

  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
}

export function countdownLabel(isoValue) {
  if (!isoValue) return null
  const endDate = new Date(isoValue)
  const diff = Math.max(0, endDate.getTime() - Date.now())
  const minutes = Math.floor(diff / 60000)
  const seconds = Math.floor((diff % 60000) / 1000)
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
}

export function startTimerUpdates(timerNodes, layer) {
  const update = () => {
    timerNodes.forEach(({ node, endDate }) => {
      const timer = countdownLabel(endDate)
      if (timer) {
        node.text(timer)
        node.show()
      } else {
        node.text("")
        node.hide()
      }
    })
    layer.batchDraw()
  }

  update()
  return setInterval(update, 1000)
}

export function createEditorSeatGroup(seat, palette, theme, options = {}) {
  const { showKeyboard = true, isSelected = false, isLocked = false, cacheBody = false, cachePixelRatio = 1 } = options

  const group = new Konva.Group({
    x: seat.x,
    y: seat.y,
    rotation: seat.rotation,
    listening: true
  })

  const bodyGroup = createSeatBodyGroup(palette, theme, { showKeyboard, isSelected, isLocked })
  if (cacheBody) {
    bodyGroup.name("seat-body")
    bodyGroup.cache({ pixelRatio: cachePixelRatio })
  }
  group.add(bodyGroup)

  addSeatStatusIcon(group, seat, palette)

  addSeatLabel(group, seat, theme, palette, { listening: true })

  if (isSelected) {
    addSelectionHighlight(group, theme)
  }

  if (isLocked) {
    group.add(createLockBadge(theme, { x: SEAT_WIDTH * 0.42, y: -SEAT_HEIGHT * 0.56 }))
  }

  group.setAttr("nodeType", "seat")
  group.setAttr("seatSlotId", seat.seat_slot_id)

  return group
}

function addSelectionHighlight(group, theme) {
  const w = SEAT_WIDTH
  const h = SEAT_HEIGHT

  group.add(new Konva.Rect({
    x: -w * 0.6,
    y: -h * 0.7,
    width: w * 1.2,
    height: h * 1.2,
    cornerRadius: 10,
    stroke: theme.accentCyan,
    strokeWidth: 3,
    shadowColor: theme.accentCyan,
    shadowBlur: 15,
    shadowOpacity: 0.6,
    perfectDrawEnabled: false,
    shadowForStrokeEnabled: false
  }))
}
