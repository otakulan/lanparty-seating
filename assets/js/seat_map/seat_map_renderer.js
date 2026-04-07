import Konva from "konva"
import { getThemeColors, getStatusColors } from "./seat_map_theme"

export const SEAT_WIDTH = 64
export const SEAT_HEIGHT = 64
export const SEAT_SCALE = 1
export const SHADOW_BLUR = 12
export const SHADOW_OPACITY = 0.6
export const ACCENT_RADIUS = 3

export function createSeatGroup(seat, palette, theme, options = {}) {
  const { showKeyboard = true, cacheBody = true } = options
  
  const group = new Konva.Group({
    x: seat.x,
    y: seat.y,
    rotation: seat.rotation || 0,
    listening: false
  })
  
  const bodyGroup = createSeatBodyGroup(palette, theme, { showKeyboard })
  if (cacheBody) {
    bodyGroup.cache()
  }
  group.add(bodyGroup)
  
  group.setAttr("nodeType", "seat")
  group.setAttr("seatSlotId", seat.seat_slot_id)
  
  return group
}

export function createSeatBodyGroup(palette, theme, options = {}) {
  const { showKeyboard = true } = options
  
  const bodyGroup = new Konva.Group({ listening: false })
  
  addSeatBody(bodyGroup, palette)
  addSeatMonitor(bodyGroup, theme)
  addSeatAccent(bodyGroup, palette)
  
  if (showKeyboard) {
    addSeatKeyboard(bodyGroup, theme)
  }
  
  return bodyGroup
}

function addSeatBody(group, palette) {
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
    stroke: palette.stroke,
    strokeWidth: 2,
    shadowColor: palette.glow,
    shadowBlur: SHADOW_BLUR,
    shadowOpacity: SHADOW_OPACITY,
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

export function addSeatLabel(group, seat, theme, palette) {
  group.add(new Konva.Text({
    x: -SEAT_WIDTH * 0.4,
    y: SEAT_HEIGHT * 0.18,
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

export function getMemberSeats(group, allSeats) {
  if (!group || !group.seat_slot_ids) return []
  return group.seat_slot_ids
    .map(id => allSeats.find(seat => seat.seat_slot_id === id))
    .filter(Boolean)
}

export function calculateBounds(seats) {
  if (!seats || seats.length === 0) {
    return { x: 0, y: 0, width: 0, height: 0 }
  }
  
  const xs = seats.map(s => s.x)
  const ys = seats.map(s => s.y)
  const widths = seats.map(s => s.width || SEAT_WIDTH)
  const heights = seats.map(s => s.height || SEAT_HEIGHT)
  
  const minX = Math.min(...xs.map((x, i) => x - widths[i] / 2))
  const maxX = Math.max(...xs.map((x, i) => x + widths[i] / 2))
  const minY = Math.min(...ys.map((y, i) => y - heights[i] / 2))
  const maxY = Math.max(...ys.map((y, i) => y + heights[i] / 2))
  
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
}

export function renderGroupBounds(layer, group, seats, theme) {
  const memberSeats = getMemberSeats(group, seats)
  if (memberSeats.length === 0) return
  
  const bounds = calculateBounds(memberSeats)
  const color = group.color || "#22c55e"
  
  const rect = new Konva.Rect({
    x: bounds.x - 12,
    y: bounds.y - 16,
    width: bounds.width + 24,
    height: bounds.height + 32,
    stroke: color,
    strokeWidth: 2,
    dash: [8, 6],
    cornerRadius: 12,
    fill: transparentColor(color, 0.08),
    perfectDrawEnabled: false,
    shadowForStrokeEnabled: false,
    listening: false
  })
  
  layer.add(rect)
  return rect
}

export function renderGroupLabel(layer, group, seats, teamAssignments, theme) {
  const hasAssignment = (teamAssignments || []).some(a => a.group_id === group.id)
  if (hasAssignment || !group.name) return
  
  const memberSeats = getMemberSeats(group, seats)
  if (memberSeats.length === 0) return
  
  const bounds = calculateBounds(memberSeats)
  const color = group.color || "#22c55e"
  
  const text = new Konva.Text({
    text: group.name,
    fontFamily: theme.fontFamily,
    fontSize: 13,
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
    fill: transparentColor(color, 0.9),
    stroke: transparentColor("#ffffff", 0.2),
    strokeWidth: 1,
    perfectDrawEnabled: false,
    shadowForStrokeEnabled: false
  }))
  
  text.position({ x: 8, y: 5 })
  labelGroup.add(text)
  layer.add(labelGroup)
  
  return labelGroup
}

export function renderTeamLabel(layer, assignment, groups, seats, theme) {
  const group = groups.find(g => g.id === assignment.group_id)
  const memberSeats = getMemberSeats(group, seats)
  
  const bounds = memberSeats.length > 0 ? calculateBounds(memberSeats) : null
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
    fill: transparentColor(assignment.color || "#06b6d4", 0.92),
    stroke: transparentColor("#ffffff", 0.2),
    strokeWidth: 1,
    shadowColor: "rgba(0, 0, 0, 0.4)",
    shadowBlur: 12,
    shadowOffset: { x: 0, y: 4 },
    shadowOpacity: 0.8,
    perfectDrawEnabled: false,
    shadowForStrokeEnabled: false
  }))
  
  text.position({ x: 10, y: 6 })
  labelGroup.add(text)
  layer.add(labelGroup)
  
  return labelGroup
}

export function transparentColor(hexColor, alpha) {
  const sanitized = (hexColor || "#22c55e").replace("#", "")
  const value = sanitized.length === 3 
    ? sanitized.split("").map(c => c + c).join("") 
    : sanitized
  const r = parseInt(value.slice(0, 2), 16)
  const g = parseInt(value.slice(2, 4), 16)
  const b = parseInt(value.slice(4, 6), 16)
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
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
  const { showKeyboard = true, isSelected = false, cacheBody = false } = options
  
  const group = new Konva.Group({
    x: seat.x,
    y: seat.y,
    rotation: seat.rotation || 0,
    listening: true
  })
  
  const bodyGroup = createEditorSeatBodyGroup(palette, theme, { showKeyboard, isSelected })
  if (cacheBody) {
    bodyGroup.cache()
  }
  group.add(bodyGroup)
  
  addSeatLabel(group, seat, theme, palette)
  
  if (isSelected) {
    addSelectionHighlight(group, theme)
  }
  
  group.setAttr("nodeType", "seat")
  group.setAttr("seatSlotId", seat.seat_slot_id)
  
  return group
}

export function createEditorSeatBodyGroup(palette, theme, options = {}) {
  const { showKeyboard = true, isSelected = false } = options
  
  const bodyGroup = new Konva.Group({ listening: false })
  
  addEditorSeatBody(bodyGroup, palette, isSelected)
  addSeatMonitor(bodyGroup, theme)
  addSeatAccent(bodyGroup, palette)
  
  if (showKeyboard) {
    addSeatKeyboard(bodyGroup, theme)
  }
  
  return bodyGroup
}

function addEditorSeatBody(group, palette, isSelected) {
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
    stroke: isSelected ? palette.accent : palette.stroke,
    strokeWidth: isSelected ? 3 : 2,
    shadowColor: palette.glow,
    shadowBlur: isSelected ? 20 : SHADOW_BLUR,
    shadowOpacity: isSelected ? 1 : SHADOW_OPACITY,
    perfectDrawEnabled: false,
    shadowForStrokeEnabled: false
  }))
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