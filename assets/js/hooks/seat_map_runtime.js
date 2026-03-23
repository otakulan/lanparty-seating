import Konva from "konva"

Konva.hitOnDragEnabled = false
Konva.captureTouchEventsEnabled = true
Konva.pixelRatio = 1

const STATUS_COLORS = {
  available: { fill: "#7aa48e", fillSecondary: "#5d8771", stroke: "#355845", text: "#f7fbf8", accent: "#cfe8d7" },
  occupied: { fill: "#f1bf4b", fillSecondary: "#da9c1f", stroke: "#9a6511", text: "#372102", accent: "#ffe5a9" },
  reserved: { fill: "#667684", fillSecondary: "#495866", stroke: "#2b3740", text: "#f4f7fb", accent: "#ced8df" },
  unavailable: { fill: "#cb6672", fillSecondary: "#a93e4d", stroke: "#6f1c28", text: "#fff5f6", accent: "#f7cfd4" },
  tournament: { fill: "#4b88a7", fillSecondary: "#2e6684", stroke: "#17445a", text: "#f2fbff", accent: "#cae4ef" }
}

const DISPLAY_FONT = "SF Pro Display, SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif"
const MONO_FONT = "SF Mono, ui-monospace, Menlo, monospace"
const COMPUTER_SHELL_PATH = "M9 8C9 5.8 10.8 4 13 4H51C53.2 4 55 5.8 55 8V31C55 33.2 53.2 35 51 35H35L37 40H45C47.2 40 49 41.8 49 44C49 46.2 47.2 48 45 48H19C16.8 48 15 46.2 15 44C15 41.8 16.8 40 19 40H27L29 35H13C10.8 35 9 33.2 9 31Z"
const KEYBOARD_PATH = "M14 50C14 48.3 15.3 47 17 47H47C48.7 47 50 48.3 50 50V53C50 54.7 48.7 56 47 56H17C15.3 56 14 54.7 14 53Z"

const SCALE_BY = 1.08

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}

function getDistance(pointA, pointB) {
  return Math.hypot(pointB.x - pointA.x, pointB.y - pointA.y)
}

function getCenter(pointA, pointB) {
  return {
    x: (pointA.x + pointB.x) / 2,
    y: (pointA.y + pointB.y) / 2
  }
}

function countdownLabel(isoValue) {
  if (!isoValue) return null
  const endDate = new Date(isoValue)
  const diff = Math.max(0, endDate.getTime() - Date.now())
  const minutes = Math.floor(diff / 60000)
  const seconds = Math.floor((diff % 60000) / 1000)
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
}

function randomId(prefix) {
  return `${prefix}-${Math.random().toString(36).slice(2, 10)}`
}

function parseInteger(value, fallback = 0) {
  if (Number.isInteger(value)) return value
  if (typeof value === "number") return Math.round(value)
  if (typeof value === "string") {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? Math.round(parsed) : fallback
  }
  return fallback
}

export default class SeatMapRuntime {
  constructor(hook, options = {}) {
    this.hook = hook
    this.el = hook.el
    this.mode = options.mode || this.el.dataset.mode || "view"
    this.editable = Boolean(options.editable)
    this.stageContainer = this.el.querySelector("[data-seat-map-stage]")
    this.exportTarget = document.querySelector(`[data-seat-map-export-for="${this.el.id}"]`)
    this.selectedSeats = new Set()
    this.selectedObjects = new Set()
    this.timerNodes = new Map()
    this.backgroundImageSrc = null
    this.backgroundImageElement = null
    this.lastTouchCenter = null
    this.lastTouchDistance = 0
    this.renderTick = null
    this.state = this.parsePayload()
    this.detailLevel = this.computeDetailLevel(1)
  }

  mount() {
    this.buildStage()
    this.bindCommands()
    this.startTicking()
    this.renderScene(true)
  }

  update() {
    this.state = this.parsePayload()
    this.renderScene(false)
  }

  destroy() {
    this.el.removeEventListener("click", this.handleCommandClick)
    window.removeEventListener("resize", this.handleResize)
    clearInterval(this.renderTick)
    if (this.stage) this.stage.destroy()
  }

  parsePayload() {
    return clone(JSON.parse(this.el.dataset.seatMap || "{}"))
  }

  buildStage() {
    this.stage = new Konva.Stage({
      container: this.stageContainer,
      width: this.stageContainer.clientWidth,
      height: this.stageContainer.clientHeight,
      draggable: this.mode !== "kiosk"
    })

    this.backgroundLayer = new Konva.Layer({ listening: false })
    this.sceneLayer = this.editable ? null : new Konva.Layer({ listening: false })
    this.objectLayer = this.editable ? new Konva.Layer() : this.sceneLayer
    this.groupLayer = this.editable ? new Konva.Layer({ listening: false }) : this.sceneLayer
    this.seatLayer = this.editable ? new Konva.Layer() : null
    this.seatVisualLayer = this.editable ? null : this.sceneLayer
    this.seatHitLayer = this.editable ? null : new Konva.Layer()
    this.overlayLayer = this.editable ? new Konva.Layer({ listening: false }) : this.sceneLayer

    this.transformer = new Konva.Transformer({
      rotateEnabled: this.editable,
      borderStroke: "#264653",
      anchorStroke: "#264653",
      anchorFill: "#f4a261",
      visible: false,
      ignoreStroke: true
    })

    this.uniqueLayers().forEach((layer) => this.stage.add(layer))

    if (this.editable) {
      this.objectLayer.add(this.transformer)
    }

    this.stage.on("wheel", (event) => this.handleWheel(event))
    this.stage.on("touchmove", (event) => this.handleTouchMove(event))
    this.stage.on("touchend", () => this.handleTouchEnd())
    this.stage.on("dragstart", () => this.handleStageDragStart())
    this.stage.on("dragend", () => this.handleStageDragEnd())
    this.stage.on("click tap", (event) => {
      if (event.target === this.stage && this.editable) this.clearSelection()
    })

    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(false)
    }

    window.addEventListener("resize", this.handleResize)
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

  startTicking() {
    if (this.editable) return

    this.renderTick = window.setInterval(() => {
      this.updateCountdowns()
    }, 1000)
  }

  renderScene(resetView) {
    this.uniqueLayers().forEach((layer) => layer.destroyChildren())
    this.timerNodes = new Map()

    if (this.editable) {
      this.objectLayer.add(this.transformer)
    }

    this.renderBackdrop()
    this.renderObjects()
    this.renderGroups()
    this.renderSeats()
    this.renderTeamLabels()
    this.updateExportTarget()
    this.updateCountdowns()

    if (resetView || !this.stage.scaleX()) {
      this.fitToStage(true)
    } else {
      this.stage.batchDraw()
    }
  }

  computeDetailLevel(scale) {
    if (this.editable) return "full"

    const seatCount = (this.state.seats || []).length
    const denseMap = seatCount >= 80

    if (scale < (denseMap ? 0.62 : 0.48)) return "minimal"
    if (scale < (denseMap ? 0.95 : 0.78)) return "medium"
    return "full"
  }

  syncDetailLevel() {
    const nextDetailLevel = this.computeDetailLevel(this.stage.scaleX() || 1)

    if (nextDetailLevel === this.detailLevel) return false

    this.detailLevel = nextDetailLevel
    this.renderScene(false)
    return true
  }

  detailConfig() {
    switch (this.detailLevel) {
      case "minimal":
        return {
          objectShadowOpacity: 0,
          groupShadowOpacity: 0.18,
          seatShadowOpacity: 0,
          seatShadowBlur: 0,
          showSeatLabels: false,
          showSeatTimers: false,
          showSeatChip: false,
          spriteMode: "minimal"
        }
      case "medium":
        return {
          objectShadowOpacity: 0.28,
          groupShadowOpacity: 0.36,
          seatShadowOpacity: 0.22,
          seatShadowBlur: 10,
          showSeatLabels: true,
          showSeatTimers: false,
          showSeatChip: true,
          spriteMode: "medium"
        }
      default:
        return {
          objectShadowOpacity: 0.8,
          groupShadowOpacity: 0.8,
          seatShadowOpacity: 0.75,
          seatShadowBlur: 22,
          showSeatLabels: true,
          showSeatTimers: true,
          showSeatChip: true,
          spriteMode: "full"
        }
    }
  }

  renderBackdrop() {
    const width = this.state.width || 1800
    const height = this.state.height || 1100

    const backdrop = new Konva.Rect({
      x: 0,
      y: 0,
      width,
      height,
      fillLinearGradientStartPoint: { x: 0, y: 0 },
      fillLinearGradientEndPoint: { x: width, y: height },
      fillLinearGradientColorStops: [0, "#faf8f4", 0.42, "#f3f5f3", 0.82, "#eef3f1", 1, "#f6f0e7"],
      stroke: "#cdbfa8",
      strokeWidth: 8,
      cornerRadius: 28,
      shadowColor: "rgba(120, 101, 77, 0.08)",
      shadowBlur: 28,
      shadowOffset: { x: 0, y: 18 },
      shadowOpacity: 0.9
    })

    const topGlow = new Konva.Circle({
      x: width * 0.24,
      y: 96,
      radius: 260,
      fill: "rgba(255,255,255,0.62)",
      listening: false
    })

    const sideGlow = new Konva.Circle({
      x: width * 0.83,
      y: height * 0.3,
      radius: 220,
      fill: "rgba(215, 236, 233, 0.32)",
      listening: false
    })

    const lowerGlow = new Konva.Circle({
      x: width * 0.68,
      y: height * 0.86,
      radius: 210,
      fill: "rgba(245, 231, 213, 0.3)",
      listening: false
    })

    this.backgroundLayer.add(backdrop)
    this.backgroundLayer.add(topGlow)
    this.backgroundLayer.add(sideGlow)
    this.backgroundLayer.add(lowerGlow)

    this.renderBackgroundAsset(width, height)
  }

  renderBackgroundAsset(width, height) {
    if (!this.state.background_kind || this.state.background_kind === "none" || !this.state.background_value) return

    const src = this.state.background_value

    if (this.backgroundImageSrc !== src) {
      this.backgroundImageSrc = src
      this.backgroundImageElement = null

      const image = new window.Image()
      image.onload = () => {
        if (this.backgroundImageSrc !== src) return
        this.backgroundImageElement = image
        this.drawBackgroundImage(width, height)
      }
      image.src = src
      return
    }

    if (this.backgroundImageElement) this.drawBackgroundImage(width, height)
  }

  drawBackgroundImage(width, height) {
    this.backgroundLayer.add(new Konva.Image({
      image: this.backgroundImageElement,
      x: 0,
      y: 0,
      width,
      height,
      opacity: 0.24,
      listening: false
    }))

    this.backgroundLayer.batchDraw()
  }

  renderObjects() {
    const detail = this.detailConfig()

    ;(this.state.objects || []).forEach((object) => {
      const id = object.id || randomId("object")
      const isText = object.type === "text"
      let node

      if (isText) {
        node = new Konva.Text({
          x: object.x,
          y: object.y,
          width: object.width,
          height: object.height,
          rotation: object.rotation || 0,
          text: object.text || "Label",
          fontSize: object.font_size || 24,
          fontStyle: "bold",
          fontFamily: DISPLAY_FONT,
          fill: object.fill || "#2f3e46",
          perfectDrawEnabled: false,
          listening: this.editable,
          draggable: this.editable
        })
      } else {
        node = new Konva.Rect({
          x: object.x,
          y: object.y,
          width: object.width,
          height: object.height,
          rotation: object.rotation || 0,
          fillLinearGradientStartPoint: { x: 0, y: 0 },
          fillLinearGradientEndPoint: { x: object.width, y: object.height },
          fillLinearGradientColorStops: [0, object.fill_secondary || object.fill || "#ede6db", 1, object.fill || "#d8c3a5"],
          stroke: object.stroke || "#8d6e63",
          strokeWidth: 2.5,
          cornerRadius: 22,
          shadowColor: "rgba(15, 23, 42, 0.09)",
          shadowBlur: 24,
          shadowOffset: { x: 0, y: 10 },
          shadowOpacity: detail.objectShadowOpacity,
          perfectDrawEnabled: false,
          listening: this.editable,
          draggable: this.editable
        })
      }

      node.id(id)
      node.setAttr("nodeType", "object")
      node.setAttr("objectId", id)

      if (this.editable) {
        node.on("click tap", (event) => this.handleObjectSelection(event, node))
        node.on("dragend transformend", () => this.syncObjectNode(node))
      }

      this.objectLayer.add(node)
    })
  }

  renderGroups() {
    const detail = this.detailConfig()

    ;(this.state.groups || []).forEach((group) => {
      const memberSeats = (group.seat_slot_ids || [])
        .map((seatId) => (this.state.seats || []).find((seat) => seat.seat_slot_id === seatId))
        .filter(Boolean)

      if (memberSeats.length === 0) return

      const bounds = this.groupBounds(memberSeats)
      const fill = this.transparentColor(group.color || "#1d4ed8", 0.06)

      this.groupLayer.add(new Konva.Rect({
        x: bounds.x - 26,
        y: bounds.y - 30,
        width: bounds.width + 52,
        height: bounds.height + 60,
        stroke: group.color || "#1d4ed8",
        strokeWidth: 2.5,
        dash: [12, 10],
        cornerRadius: 30,
        fill,
        shadowColor: this.transparentColor(group.color || "#1d4ed8", 0.14),
        shadowBlur: 22,
        shadowOpacity: detail.groupShadowOpacity,
        perfectDrawEnabled: false,
        listening: false
      }))

      const hasTeamAssignment = (this.state.team_assignments || []).some((assignment) => assignment.group_id === group.id)

      if (!hasTeamAssignment && group.name) {
        const text = new Konva.Text({
          text: group.name,
          fontFamily: DISPLAY_FONT,
          fontStyle: "700",
          fontSize: 12,
          fill: "#f8fafc",
          listening: false
        })

        const width = text.width() + 20
        const height = text.height() + 10
        const labelGroup = new Konva.Group({
          x: bounds.x + bounds.width / 2 - width / 2,
          y: bounds.y + bounds.height / 2 - height / 2,
          listening: false
        })

        labelGroup.add(new Konva.Rect({
          x: 0,
          y: 0,
          width,
          height,
          cornerRadius: 999,
          fill: this.transparentColor(group.color || "#1d4ed8", 0.84),
          stroke: this.transparentColor("#ffffff", 0.24),
          strokeWidth: 1,
          shadowColor: this.transparentColor(group.color || "#1d4ed8", 0.28),
          shadowBlur: 18,
          shadowOffset: { x: 0, y: 10 },
          shadowOpacity: detail.groupShadowOpacity,
          perfectDrawEnabled: false
        }))

        text.position({ x: 10, y: 5 })
        labelGroup.add(text)
        this.groupLayer.add(labelGroup)
      }
    })
  }

  renderSeats() {
    const detail = this.detailConfig()

    ;(this.state.seats || []).forEach((seat) => {
      const palette = STATUS_COLORS[seat.status] || STATUS_COLORS.available
      const seatWidth = seat.width || 78
      const seatHeight = seat.height || 78
      const scale = Math.min(seatWidth, seatHeight) / 64
      const seatGroup = new Konva.Group({
        x: seat.x,
        y: seat.y,
        rotation: seat.rotation || 0,
        draggable: this.editable
      })

      seatGroup.add(new Konva.Ellipse({
        x: 0,
        y: 16,
        radiusX: seatWidth * 0.56,
        radiusY: 14,
        fill: this.transparentColor(palette.stroke, 0.16),
        blurRadius: detail.seatShadowBlur,
        opacity: detail.seatShadowOpacity > 0 ? 1 : 0,
        perfectDrawEnabled: false,
        listening: false
      }))

      if (detail.spriteMode === "minimal") {
        seatGroup.add(new Konva.Rect({
          x: -seatWidth * 0.34,
          y: -seatHeight * 0.3,
          width: seatWidth * 0.68,
          height: seatHeight * 0.52,
          cornerRadius: 10,
          fillLinearGradientStartPoint: { x: 0, y: 0 },
          fillLinearGradientEndPoint: { x: seatWidth * 0.68, y: seatHeight * 0.52 },
          fillLinearGradientColorStops: [0, palette.fillSecondary, 1, palette.fill],
          stroke: palette.stroke,
          strokeWidth: 1.6,
          perfectDrawEnabled: false,
          listening: false
        }))

        seatGroup.add(new Konva.Rect({
          x: -seatWidth * 0.22,
          y: -seatHeight * 0.18,
          width: seatWidth * 0.44,
          height: seatHeight * 0.18,
          cornerRadius: 5,
          fill: this.transparentColor("#ffffff", 0.75),
          stroke: this.transparentColor("#ffffff", 0.45),
          strokeWidth: 0.8,
          perfectDrawEnabled: false,
          listening: false
        }))

        seatGroup.add(new Konva.Circle({
          x: seatWidth * 0.16,
          y: -seatHeight * 0.05,
          radius: 3.2,
          fill: palette.accent,
          perfectDrawEnabled: false,
          listening: false
        }))
      } else {
        seatGroup.add(new Konva.Path({
          data: COMPUTER_SHELL_PATH,
          x: -32 * scale,
          y: -32 * scale,
          scaleX: scale,
          scaleY: scale,
          fillLinearGradientStartPoint: { x: 0, y: 0 },
          fillLinearGradientEndPoint: { x: 64 * scale, y: 56 * scale },
          fillLinearGradientColorStops: [0, palette.fillSecondary, 1, palette.fill],
          stroke: this.selectedSeats.has(seat.seat_slot_id) ? palette.accent : palette.stroke,
          strokeWidth: this.selectedSeats.has(seat.seat_slot_id) ? 3 : 2,
          shadowColor: this.transparentColor(palette.stroke, 0.22),
          shadowBlur: detail.seatShadowBlur,
          shadowOffset: { x: 0, y: 10 },
          shadowOpacity: detail.seatShadowOpacity,
          perfectDrawEnabled: false
        }))

        seatGroup.add(new Konva.Rect({
          x: -seatWidth * 0.28,
          y: -seatHeight * 0.31,
          width: seatWidth * 0.56,
          height: seatHeight * 0.3,
          cornerRadius: 8,
          fillLinearGradientStartPoint: { x: 0, y: 0 },
          fillLinearGradientEndPoint: { x: seatWidth * 0.56, y: seatHeight * 0.3 },
          fillLinearGradientColorStops: [0, this.transparentColor("#ffffff", 0.82), 1, palette.accent],
          stroke: this.transparentColor("#ffffff", 0.5),
          strokeWidth: 1.5,
          perfectDrawEnabled: false,
          listening: false
        }))

        seatGroup.add(new Konva.Path({
          data: KEYBOARD_PATH,
          x: -32 * scale,
          y: -32 * scale,
          scaleX: scale,
          scaleY: scale,
          fill: this.transparentColor("#ffffff", 0.45),
          stroke: this.transparentColor(palette.stroke, 0.35),
          strokeWidth: 1.3,
          perfectDrawEnabled: false,
          listening: false
        }))

        seatGroup.add(new Konva.Circle({
          x: seatWidth * 0.24,
          y: -seatHeight * 0.1,
          radius: 3.8,
          fill: palette.accent,
          perfectDrawEnabled: false,
          listening: false
        }))
      }

      if (detail.showSeatChip) {
        seatGroup.add(new Konva.Rect({
          x: -seatWidth * 0.35,
          y: seatHeight * 0.26,
          width: seatWidth * 0.7,
          height: 18,
          cornerRadius: 999,
          fill: this.transparentColor("#ffffff", 0.88),
          stroke: this.transparentColor(palette.stroke, 0.16),
          strokeWidth: 1,
          perfectDrawEnabled: false,
          listening: false
        }))
      }

      if (detail.showSeatLabels) {
        seatGroup.add(new Konva.Text({
          x: -seatWidth * 0.35,
          y: seatHeight * 0.29,
          width: seatWidth * 0.7,
          align: "center",
          text: seat.label,
          fontSize: detail.spriteMode === "medium" ? 9.5 : 10.5,
          fontStyle: "700",
          fontFamily: DISPLAY_FONT,
          fill: detail.showSeatChip ? "#31424d" : this.transparentColor("#ffffff", 0.92),
          perfectDrawEnabled: false,
          listening: false
        }))
      }

      const timerNode = new Konva.Text({
        x: -seatWidth * 0.3,
        y: seatHeight * 0.06,
        width: seatWidth * 0.6,
        align: "center",
        text: "",
        fontSize: 9,
        fontStyle: "bold",
        fontFamily: MONO_FONT,
        fill: palette.text,
        perfectDrawEnabled: false,
        listening: false,
        visible: false
      })

      if (detail.showSeatTimers) {
        seatGroup.add(timerNode)
      }

      if (detail.showSeatTimers && seat.reservation_end_date) {
        this.timerNodes.set(seat.seat_slot_id, {
          node: timerNode,
          reservationEndDate: seat.reservation_end_date
        })
      }

      seatGroup.id(`seat-${seat.seat_slot_id}`)
      seatGroup.setAttr("nodeType", "seat")
      seatGroup.setAttr("seatSlotId", seat.seat_slot_id)

      if (this.editable) {
        seatGroup.on("click tap", (event) => this.handleSeatInteraction(event, seat))
        seatGroup.on("dragend transformend", () => this.syncSeatNode(seatGroup, seat.seat_slot_id))
        this.seatLayer.add(seatGroup)
        return
      }

      this.seatVisualLayer.add(seatGroup)

      if (this.mode !== "kiosk") {
        const hitTarget = new Konva.Rect({
          x: seat.x - seatWidth * 0.55,
          y: seat.y - seatHeight * 0.6,
          width: seatWidth * 1.1,
          height: seatHeight * 1.25,
          cornerRadius: 12,
          fill: "rgba(0,0,0,0.01)",
          strokeWidth: 0,
          perfectDrawEnabled: false
        })

        hitTarget.on("click tap", (event) => this.handleSeatInteraction(event, seat))
        this.seatHitLayer.add(hitTarget)
      }
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

    if (this.editable) this.seatLayer.batchDraw()
    else this.sceneLayer.batchDraw()
  }

  renderTeamLabels() {
    ;(this.state.team_assignments || []).forEach((assignment) => {
      const group = (this.state.groups || []).find((entry) => entry.id === assignment.group_id)
      const memberSeats = group
        ? (group.seat_slot_ids || [])
            .map((seatId) => (this.state.seats || []).find((seat) => seat.seat_slot_id === seatId))
            .filter(Boolean)
        : []

      const bounds = memberSeats.length > 0 ? this.groupBounds(memberSeats) : null
      const x = bounds ? bounds.x + bounds.width / 2 : (assignment.label_x || 0)
      const y = bounds ? bounds.y + bounds.height / 2 - 12 : (assignment.label_y || 0)

      const text = new Konva.Text({
        text: `${assignment.team_name} · ${assignment.tournament_name}`,
        fontFamily: DISPLAY_FONT,
        fontStyle: "700",
        fontSize: 13,
        letterSpacing: 0.15,
        fill: "#f8fafc",
        padding: 0,
        perfectDrawEnabled: false,
        listening: false
      })

      const width = text.width() + 24
      const height = text.height() + 12
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
        cornerRadius: 999,
        fill: this.transparentColor(assignment.color || "#264653", 0.92),
        stroke: this.transparentColor("#ffffff", 0.26),
        strokeWidth: 1,
        shadowColor: "rgba(15, 23, 42, 0.22)",
        shadowBlur: 18,
        shadowOffset: { x: 0, y: 10 },
        shadowOpacity: 0.8,
        perfectDrawEnabled: false
      }))

      text.position({ x: 12, y: 6 })
      labelGroup.add(text)

      this.overlayLayer.add(labelGroup)
    })
  }

  handleSeatInteraction(event, seat) {
    if (this.editable) {
      if (event.evt.shiftKey) {
        if (this.selectedSeats.has(seat.seat_slot_id)) this.selectedSeats.delete(seat.seat_slot_id)
        else this.selectedSeats.add(seat.seat_slot_id)
      } else {
        this.selectedSeats = new Set([seat.seat_slot_id])
        this.selectedObjects.clear()
      }

      this.transformer.visible(false)
      this.renderScene(false)
      return
    }

    this.hook.pushEvent("seat_selected", {
      seat_slot_id: seat.seat_slot_id,
      label: seat.label,
      status: seat.status
    })
  }

  handleObjectSelection(event, node) {
    event.cancelBubble = true
    this.selectedObjects = new Set([node.getAttr("objectId")])
    this.selectedSeats.clear()
    this.transformer.nodes([node])
    this.transformer.visible(true)
    this.objectLayer.batchDraw()
  }

  syncObjectNode(node) {
    const objectId = node.getAttr("objectId")
    this.state.objects = (this.state.objects || []).map((object) => {
      if (object.id !== objectId) return object

      return {
        ...object,
        x: Math.round(node.x()),
        y: Math.round(node.y()),
        width: Math.round(node.width() * node.scaleX()),
        height: Math.round(node.height() * node.scaleY()),
        rotation: Math.round(node.rotation())
      }
    })

    node.scale({ x: 1, y: 1 })
    this.renderScene(false)
  }

  syncSeatNode(node, seatSlotId) {
    this.state.seats = (this.state.seats || []).map((seat) => {
      if (seat.seat_slot_id !== seatSlotId) return seat
      return {
        ...seat,
        x: Math.round(node.x()),
        y: Math.round(node.y()),
        rotation: Math.round(node.rotation())
      }
    })
    this.renderScene(false)
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
      case "add-seat":
        if (this.editable) this.addSeatAtViewportCenter()
        break
      case "add-table":
        if (this.editable) this.addObject("rect")
        break
      case "add-label":
        if (this.editable) this.addObject("text")
        break
      case "group-selection":
        if (this.editable) this.createGroupFromSelection()
        break
      case "delete-selection":
        if (this.editable) this.deleteSelection()
        break
      case "export-json":
        this.updateExportTarget(true)
        break
      case "save-draft":
        if (this.editable) this.hook.pushEvent("save_draft_preview", { map: this.serializableState() })
        break
      case "publish-preview":
        if (this.editable) this.hook.pushEvent("publish_preview", { map: this.serializableState() })
        break
      default:
        break
    }
  }

  addSeatAtViewportCenter() {
    const point = this.viewportCenter()
    this.state.seats = [
      ...(this.state.seats || []),
      {
        seat_slot_id: this.nextSeatId(),
        label: this.nextSeatLabel(),
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: 82,
        height: 82,
        rotation: 0,
        shape: "rect",
        status: "available",
        reservation_end_date: null
      }
    ]
    this.renderScene(false)
  }

  addObject(type) {
    const point = this.viewportCenter()
    const base = {
      id: randomId(type),
      type,
      x: Math.round(point.x - 80),
      y: Math.round(point.y - 40),
      width: type === "text" ? 240 : 180,
      height: type === "text" ? 48 : 90,
      rotation: 0,
      fill: type === "text" ? "#264653" : "#d8c3a5",
      stroke: type === "text" ? "transparent" : "#8d6e63",
      text: type === "text" ? "New label / Nouveau label" : undefined
    }

    this.state.objects = [...(this.state.objects || []), base]
    this.renderScene(false)
  }

  createGroupFromSelection() {
    if (this.selectedSeats.size < 2) return
    this.state.groups = [
      ...(this.state.groups || []),
      {
        id: randomId("group"),
        name: `Group ${String((this.state.groups || []).length + 1).padStart(2, "0")}`,
        seat_slot_ids: Array.from(this.selectedSeats),
        color: "#1d4ed8"
      }
    ]
    this.renderScene(false)
  }

  deleteSelection() {
    if (this.selectedSeats.size > 0) {
      const selectedSeatIds = this.selectedSeats
      this.state.seats = (this.state.seats || []).filter((seat) => !selectedSeatIds.has(seat.seat_slot_id))
      this.state.groups = (this.state.groups || []).map((group) => ({
        ...group,
        seat_slot_ids: (group.seat_slot_ids || []).filter((id) => !selectedSeatIds.has(id))
      }))
      this.selectedSeats.clear()
    }

    if (this.selectedObjects.size > 0) {
      const selectedObjectIds = this.selectedObjects
      this.state.objects = (this.state.objects || []).filter((object) => !selectedObjectIds.has(object.id))
      this.selectedObjects.clear()
      this.transformer.visible(false)
    }

    this.renderScene(false)
  }

  updateExportTarget(selectText = false) {
    if (!this.exportTarget) return
    this.exportTarget.value = JSON.stringify(this.serializableState(), null, 2)
    if (selectText) this.exportTarget.select()
  }

  serializableState() {
    return {
      ...this.state,
      revision: parseInteger(this.state.revision, 1),
      seats: (this.state.seats || []).map((seat) => ({ ...seat })),
      objects: (this.state.objects || []).map((object) => ({ ...object })),
      groups: (this.state.groups || []).map((group) => ({ ...group }))
    }
  }

  scaleStage(nextScale) {
    const meta = this.state.meta || {}
    const clampedScale = clamp(nextScale, meta.minScale || 0.4, meta.maxScale || 4)
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
    if (!this.syncDetailLevel()) this.stage.batchDraw()
  }

  fitToStage(resetPosition) {
    const padding = 72
    const width = this.state.width || 1800
    const height = this.state.height || 1100
    const scale = Math.min((this.stage.width() - padding) / width, (this.stage.height() - padding) / height, 1)
    const clampedScale = clamp(scale, (this.state.meta || {}).minScale || 0.4, (this.state.meta || {}).maxScale || 4)

    if (resetPosition) {
      this.stage.scale({ x: clampedScale, y: clampedScale })
      this.stage.position({
        x: (this.stage.width() - width * clampedScale) / 2,
        y: (this.stage.height() - height * clampedScale) / 2
      })
    }

    if (!this.syncDetailLevel()) this.stage.batchDraw()
  }

  viewportCenter() {
    const scale = this.stage.scaleX() || 1
    return {
      x: (this.stage.width() / 2 - this.stage.x()) / scale,
      y: (this.stage.height() / 2 - this.stage.y()) / scale
    }
  }

  handleWheel(event) {
    if (this.mode === "kiosk") return

    event.evt.preventDefault()
    const oldScale = this.stage.scaleX() || 1
    const pointer = this.stage.getPointerPosition()
    const pointTo = {
      x: (pointer.x - this.stage.x()) / oldScale,
      y: (pointer.y - this.stage.y()) / oldScale
    }

    let direction = event.evt.deltaY > 0 ? 1 : -1
    if (event.evt.ctrlKey) direction = -direction
    const nextScale = direction > 0 ? oldScale / SCALE_BY : oldScale * SCALE_BY
    const clampedScale = clamp(nextScale, (this.state.meta || {}).minScale || 0.4, (this.state.meta || {}).maxScale || 4)

    this.stage.scale({ x: clampedScale, y: clampedScale })
    this.stage.position({
      x: pointer.x - pointTo.x * clampedScale,
      y: pointer.y - pointTo.y * clampedScale
    })
    if (!this.syncDetailLevel()) this.stage.batchDraw()
  }

  handleTouchMove(event) {
    if (this.mode === "kiosk") return

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
      const clampedScale = clamp(scale, (this.state.meta || {}).minScale || 0.4, (this.state.meta || {}).maxScale || 4)
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
      if (!this.syncDetailLevel()) this.stage.batchDraw()
    } else {
      this.stage.draggable(this.mode !== "kiosk")
    }
  }

  handleTouchEnd() {
    this.lastTouchCenter = null
    this.lastTouchDistance = 0
    this.stage.draggable(this.mode !== "kiosk")
    this.handleStageDragEnd()
  }

  handleStageDragStart() {
    if (this.seatLayer) this.seatLayer.listening(false)
    if (this.seatHitLayer) this.seatHitLayer.listening(false)
    if (this.editable) this.objectLayer.listening(false)
  }

  handleStageDragEnd() {
    if (this.editable && this.mode !== "kiosk") this.seatLayer.listening(true)
    if (this.seatHitLayer && this.mode !== "kiosk") this.seatHitLayer.listening(true)
    if (this.editable) this.objectLayer.listening(true)
    if (this.sceneLayer) this.sceneLayer.batchDraw()
    if (this.seatLayer) this.seatLayer.batchDraw()
    if (this.seatHitLayer) this.seatHitLayer.batchDraw()
    if (this.editable) this.objectLayer.batchDraw()
  }

  uniqueLayers() {
    return [...new Set([
      this.backgroundLayer,
      this.sceneLayer,
      this.objectLayer,
      this.groupLayer,
      this.seatLayer,
      this.seatVisualLayer,
      this.seatHitLayer,
      this.overlayLayer
    ].filter(Boolean))]
  }

  clearSelection() {
    this.selectedSeats.clear()
    this.selectedObjects.clear()
    this.transformer.nodes([])
    this.transformer.visible(false)
    this.renderScene(false)
  }

  groupBounds(seats) {
    const xs = seats.map((seat) => seat.x)
    const ys = seats.map((seat) => seat.y)
    const widths = seats.map((seat) => seat.width || 82)
    const heights = seats.map((seat) => seat.height || 82)
    const minX = Math.min(...xs.map((x, index) => x - widths[index] / 2))
    const maxX = Math.max(...xs.map((x, index) => x + widths[index] / 2))
    const minY = Math.min(...ys.map((y, index) => y - heights[index] / 2))
    const maxY = Math.max(...ys.map((y, index) => y + heights[index] / 2))

    return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
  }

  transparentColor(hexColor, alpha) {
    const sanitized = (hexColor || "#1d4ed8").replace("#", "")
    const value = sanitized.length === 3 ? sanitized.split("").map((part) => `${part}${part}`).join("") : sanitized
    const red = parseInt(value.slice(0, 2), 16)
    const green = parseInt(value.slice(2, 4), 16)
    const blue = parseInt(value.slice(4, 6), 16)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
  }

  nextSeatId() {
    const ids = (this.state.seats || []).map((seat) => Number(seat.seat_slot_id) || 0)
    return Math.max(0, ...ids) + 1
  }

  nextSeatLabel() {
    const labels = new Set((this.state.seats || []).map((seat) => seat.label))
    for (let row = 0; row < 26; row += 1) {
      const prefix = String.fromCharCode(65 + row)
      for (let column = 1; column <= 99; column += 1) {
        const label = `${prefix}${String(column).padStart(2, "0")}`
        if (!labels.has(label)) return label
      }
    }
    return `Z${String((this.state.seats || []).length + 1).padStart(2, "0")}`
  }
}
