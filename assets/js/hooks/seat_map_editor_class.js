import Konva from "konva"
import {
  SeatMapBase,
  STATUS_COLORS,
  THEME,
  SCALE_BY,
  clamp,
  randomId,
  groupBounds
} from "./seat_map_base"

const SEAT_WIDTH = 64
const SEAT_HEIGHT = 64

function renderEditorSeat(seatGroup, seat, palette, scale, showKeyboard = true, isSelected = false) {
  const w = SEAT_WIDTH * scale
  const h = SEAT_HEIGHT * scale
  
  const strokeWidth = isSelected ? 3 : 2
  const stroke = isSelected ? palette.accent : palette.stroke
  
  seatGroup.add(new Konva.Rect({
    x: -w / 2,
    y: -h * 0.6,
    width: w,
    height: h * 0.75,
    cornerRadius: 6,
    fillLinearGradientStartPoint: { x: 0, y: 0 },
    fillLinearGradientEndPoint: { x: w, y: h * 0.75 },
    fillLinearGradientColorStops: [0, palette.fillSecondary, 0.5, palette.fill, 1, palette.fill],
    stroke,
    strokeWidth,
    shadowColor: palette.glow,
    shadowBlur: isSelected ? 20 : 12,
    shadowOpacity: isSelected ? 1 : 0.6,
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
      fill: "rgba(139, 148, 158, 0.12)",
      stroke: "rgba(139, 148, 158, 0.25)",
      strokeWidth: 1,
      perfectDrawEnabled: false
    }))
  }
  
  seatGroup.add(new Konva.Text({
    x: -w * 0.4,
    y: h * 0.14,
    width: w * 0.8,
    align: "center",
    text: seat.label,
    fontSize: 11,
    fontStyle: "600",
    fontFamily: THEME.fontFamily,
    fill: palette.text,
    perfectDrawEnabled: false
  }))
}

export default class SeatMapEditor extends SeatMapBase {
  constructor(hook, options = {}) {
    super(hook, options)
    this.showKeyboard = options.showKeyboard !== false
    this.selectedSeats = new Set()
    this.selectedObjects = new Set()
    this.lastTouchCenter = null
    this.lastTouchDistance = 0
    this.renderFrame = null
    this.isDragging = false
    this.marqueeRect = null
    this.marqueeStartPos = null
    this.marqueeStartPosTransformed = null
    this.lastSelectionModifier = null
  }
  
  mount() {
    this.buildStage()
    this.bindCommands()
    this.renderScene(true)
  }
  
  buildStage() {
    this.stage = new Konva.Stage({
      container: this.stageContainer,
      width: this.stageContainer.clientWidth,
      height: this.stageContainer.clientHeight,
      draggable: true
    })
    
    this.backgroundLayer = new Konva.Layer({ listening: false })
    this.groupLayer = new Konva.Layer({ listening: false })
    this.seatLayer = new Konva.Layer()
    this.objectLayer = new Konva.Layer()
    this.overlayLayer = new Konva.Layer({ listening: false })
    
    this.transformer = new Konva.Transformer({
      rotateEnabled: true,
      borderStroke: THEME.accentCyan,
      anchorStroke: THEME.accentCyan,
      anchorFill: THEME.accentGreen,
      anchorSize: 8,
      anchorCornerRadius: 3,
      visible: false,
      ignoreStroke: true
    })
    
    this.objectLayer.add(this.transformer)
    
    this.stage.add(this.backgroundLayer)
    this.stage.add(this.groupLayer)
    this.stage.add(this.seatLayer)
    this.stage.add(this.objectLayer)
    this.stage.add(this.overlayLayer)
    
    this.stage.on("wheel", (event) => this.handleWheel(event))
    this.stage.on("touchmove", (event) => this.handleTouchMove(event))
    this.stage.on("touchend", () => this.handleTouchEnd())
    this.stage.on("click tap", (event) => this.handleStageClick(event))
    this.stage.on("dragstart", () => this.handleDragStart())
    this.stage.on("dragend", () => this.handleDragEnd())
    
    this.stage.on("mousedown", (event) => {
      if (event.target === this.stage && event.evt.button === 0) {
        this.isDragging = true
        this.lastSelectionModifier = event.evt.ctrlKey ? 'ctrl' : event.evt.metaKey ? 'meta' : event.evt.shiftKey ? 'shift' : null
        const pos = this.stage.getPointerPosition()
        this.marqueeStartPos = pos
        this.marqueeStartPosTransformed = pos ? {
          x: (pos.x - this.stage.x()) / this.stage.scaleX(),
          y: (pos.y - this.stage.y()) / this.stage.scaleY()
        } : null
      }
    })
    
    this.stage.on("mousemove", (event) => {
      if (this.isDragging && this.marqueeStartPos && event.target === this.stage) {
        this.handleMarqueeMove(event)
      }
    })
    
    this.stage.on("mouseup", (event) => {
      if (this.isDragging && this.marqueeStartPos) {
        this.handleMarqueeEnd()
      }
      this.isDragging = false
    })
    
    this.stageContainer.addEventListener("keydown", (e) => {
      if (e.key === "Delete" || e.key === "Backspace") {
        if (this.selectedSeats.size > 0 || this.selectedObjects.size > 0) {
          e.preventDefault()
          this.deleteSelection()
        }
      }
    })
    
    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(true)
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
  
  destroy() {
    this.el.removeEventListener("click", this.handleCommandClick)
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
    this.groupLayer.destroyChildren()
    this.seatLayer.destroyChildren()
    this.objectLayer.destroyChildren()
    this.overlayLayer.destroyChildren()
    
    this.objectLayer.add(this.transformer)
    
    const width = this.state.width || 1920
    const height = this.state.height || 1080
    
    this.renderBackdrop(width, height)
    this.renderObjects()
    this.renderGroups()
    this.renderSeats()
    this.renderTeamLabels()
    this.updateExportTarget()
    
    if (resetView || !this.stage.scaleX()) {
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
      },
      listening: false
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
          opacity: 0.15,
          listening: false
        }))
        this.backgroundLayer.batchDraw()
      }
      image.src = this.state.background_value
    }
  }
  
  renderObjects() {
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
          fontStyle: "600",
          fontFamily: THEME.fontFamily,
          fill: object.fill || THEME.textPrimary,
          perfectDrawEnabled: false
        })
      } else {
        node = new Konva.Rect({
          x: object.x,
          y: object.y,
          width: object.width,
          height: object.height,
          rotation: object.rotation || 0,
          fill: object.fill || "rgba(34, 197, 94, 0.2)",
          stroke: object.stroke || THEME.accentGreen,
          strokeWidth: 2,
          cornerRadius: 12,
          shadowColor: "rgba(34, 197, 94, 0.3)",
          shadowBlur: 16,
          shadowOpacity: 0.6,
          perfectDrawEnabled: false
        })
      }
      
      node.id(id)
      node.setAttr("nodeType", "object")
      node.setAttr("objectId", id)
      node.draggable(true)
      
      node.on("click tap", (event) => this.handleObjectSelection(event, node))
      node.on("dragend transformend", () => this.syncObjectNode(node))
      
      this.objectLayer.add(node)
    })
  }
  
  renderGroups() {
    ;(this.state.groups || []).forEach((group) => {
      const memberSeats = (group.seat_slot_ids || [])
        .map((seatId) => (this.state.seats || []).find((seat) => seat.seat_slot_id === seatId))
        .filter(Boolean)
      
      if (memberSeats.length === 0) return
      
      const bounds = groupBounds(memberSeats)
      const color = group.color || THEME.accentGreen
      
      this.groupLayer.add(new Konva.Rect({
        x: bounds.x - 12,
        y: bounds.y - 16,
        width: bounds.width + 24,
        height: bounds.height + 32,
        stroke: color,
        strokeWidth: 2,
        dash: [8, 6],
        cornerRadius: 12,
        fill: this.transparentColor(color, 0.1),
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
        this.groupLayer.add(labelGroup)
      }
    })
  }
  
  renderSeats() {
    const scale = 1
    
    ;(this.state.seats || []).forEach((seat) => {
      const palette = STATUS_COLORS[seat.status] || STATUS_COLORS.available
      const isSelected = this.selectedSeats.has(seat.seat_slot_id)
      
      const seatGroup = new Konva.Group({
        x: seat.x,
        y: seat.y,
        rotation: seat.rotation || 0,
        draggable: true
      })
      
      seatGroup.id(`seat-${seat.seat_slot_id}`)
      seatGroup.setAttr("nodeType", "seat")
      seatGroup.setAttr("seatSlotId", seat.seat_slot_id)
      
      renderEditorSeat(seatGroup, seat, palette, scale, this.showKeyboard, isSelected)
      
      seatGroup.on("click tap", (event) => this.handleSeatClick(event, seat))
      seatGroup.on("dragend", () => this.syncSeatNode(seatGroup, seat.seat_slot_id))
      
      this.seatLayer.add(seatGroup)
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
        fontSize: 11,
        fontStyle: "600",
        fill: THEME.textPrimary,
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
  
  handleStageClick(event) {
    if (this.isDragging && this.marqueeRect) {
      return
    }
    
    if (event.target === this.stage) {
      this.clearSelection()
    }
  }
  
  handleSeatClick(event, seat) {
    event.cancelBubble = true
    
    const isMultiSelect = event.evt.shiftKey || event.evt.ctrlKey || event.evt.metaKey
    
    if (isMultiSelect) {
      if (this.selectedSeats.has(seat.seat_slot_id)) {
        this.selectedSeats.delete(seat.seat_slot_id)
      } else {
        this.selectedSeats.add(seat.seat_slot_id)
      }
    } else {
      this.selectedSeats = new Set([seat.seat_slot_id])
      this.selectedObjects.clear()
    }
    
    this.transformer.visible(false)
    this.scheduleRender(false)
  }
  
  handleObjectSelection(event, node) {
    event.cancelBubble = true
    
    const isMultiSelect = event.evt.shiftKey || event.evt.ctrlKey || event.evt.metaKey
    const objectId = node.getAttr("objectId")
    
    if (isMultiSelect) {
      if (this.selectedObjects.has(objectId)) {
        this.selectedObjects.delete(objectId)
        const currentNodes = this.transformer.nodes()
        this.transformer.nodes(currentNodes.filter(n => n !== node))
      } else {
        this.selectedObjects.add(objectId)
        this.transformer.nodes([...this.transformer.nodes(), node])
      }
      this.selectedSeats.clear()
    } else {
      this.selectedObjects = new Set([objectId])
      this.selectedSeats.clear()
      this.transformer.nodes([node])
    }
    
    this.transformer.visible(this.selectedObjects.size > 0)
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
    this.scheduleRender(false)
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
    this.scheduleRender(false)
  }
  
  clearSelection() {
    this.selectedSeats.clear()
    this.selectedObjects.clear()
    this.transformer.nodes([])
    this.transformer.visible(false)
    this.scheduleRender(false)
  }
  
  handleSelectionStart(event) {
    if (event.evt.button !== 0 && event.evt.touches?.length !== 1) return
    if (event.target !== this.stage && event.target.parent !== this.seatLayer) return
    
    const pos = this.stage.getPointerPosition()
    if (!pos) return
    
    this.isMarqueeSelecting = true
    this.marqueeStartPos = {
      x: (pos.x - this.stage.x()) / this.stage.scaleX(),
      y: (pos.y - this.stage.y()) / this.stage.scaleY()
    }
  }
  
  handleMarqueeMove(event) {
    if (!this.isDragging) return
    
    const pos = this.stage.getPointerPosition()
    if (!pos) return
    
    const currentPos = {
      x: (pos.x - this.stage.x()) / this.stage.scaleX(),
      y: (pos.y - this.stage.y()) / this.stage.scaleY()
    }
    
    if (!this.marqueeRect) {
      this.marqueeRect = new Konva.Rect({
        fill: "rgba(6, 182, 212, 0.15)",
        stroke: THEME.accentCyan,
        strokeWidth: 2,
        dash: [4, 4],
        listening: false
      })
      this.overlayLayer.add(this.marqueeRect)
    }
    
    const startPos = this.marqueeStartPosTransformed || currentPos
    const x = Math.min(startPos.x, currentPos.x)
    const y = Math.min(startPos.y, currentPos.y)
    const width = Math.abs(currentPos.x - startPos.x)
    const height = Math.abs(currentPos.y - startPos.y)
    
    this.marqueeRect.setAttrs({ x, y, width, height })
    this.overlayLayer.batchDraw()
  }
  
  handleMarqueeEnd() {
    if (!this.isDragging) return
    
    this.isDragging = false
    
    if (this.marqueeRect) {
      const marqueeBox = {
        x: this.marqueeRect.x(),
        y: this.marqueeRect.y(),
        width: this.marqueeRect.width(),
        height: this.marqueeRect.height()
      }
      
      if (marqueeBox.width > 5 && marqueeBox.height > 5) {
        this.selectSeatsInRect(marqueeBox)
      }
      
      this.marqueeRect.destroy()
      this.marqueeRect = null
      this.overlayLayer.batchDraw()
    }
    
    this.marqueeStartPos = null
    this.marqueeStartPosTransformed = null
    this.lastSelectionModifier = null
  }
  
  selectSeatsInRect(rect) {
    const isCtrlOrMeta = this.lastSelectionModifier === 'ctrl' || this.lastSelectionModifier === 'meta'
    
    if (!isCtrlOrMeta) {
      this.selectedSeats.clear()
      this.selectedObjects.clear()
    }
    
    (this.state.seats || []).forEach((seat) => {
      const seatBounds = {
        x: seat.x - SEAT_WIDTH / 2,
        y: seat.y - SEAT_HEIGHT / 2,
        width: SEAT_WIDTH,
        height: SEAT_HEIGHT
      }
      
      if (this.rectanglesIntersect(rect, seatBounds)) {
        if (isCtrlOrMeta && this.selectedSeats.has(seat.seat_slot_id)) {
          this.selectedSeats.delete(seat.seat_slot_id)
        } else {
          this.selectedSeats.add(seat.seat_slot_id)
        }
      }
    })
    
    (this.state.objects || []).forEach((obj) => {
      const objBounds = {
        x: obj.x,
        y: obj.y,
        width: obj.width || 100,
        height: obj.height || 60
      }
      
      if (this.rectanglesIntersect(rect, objBounds)) {
        if (isCtrlOrMeta && this.selectedObjects.has(obj.id)) {
          this.selectedObjects.delete(obj.id)
        } else {
          this.selectedObjects.add(obj.id)
        }
      }
    })
    
    this.transformer.visible(false)
    this.scheduleRender(false)
  }
  
  rectanglesIntersect(a, b) {
    return !(a.x + a.width < b.x ||
              b.x + b.width < a.x ||
              a.y + a.height < b.y ||
              b.y + b.height < a.y)
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
        this.addSeatAtViewportCenter()
        break
      case "add-table":
        this.addObject("rect")
        break
      case "add-label":
        this.addObject("text")
        break
      case "group-selection":
        this.createGroupFromSelection()
        break
      case "delete-selection":
        this.deleteSelection()
        break
      case "export-json":
        this.updateExportTarget(true)
        break
      case "save-draft":
        this.hook.pushEvent("save_draft_preview", { map: this.serializableState() })
        break
      case "publish-preview":
        this.hook.pushEvent("publish_preview", { map: this.serializableState() })
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
        width: SEAT_WIDTH,
        height: SEAT_HEIGHT,
        rotation: 0,
        shape: "rect",
        status: "available",
        reservation_end_date: null
      }
    ]
    this.scheduleRender(false)
  }
  
  addObject(type) {
    const point = this.viewportCenter()
    const base = {
      id: randomId(type),
      type,
      x: Math.round(point.x - 60),
      y: Math.round(point.y - 30),
      width: type === "text" ? 180 : 120,
      height: type === "text" ? 36 : 60,
      rotation: 0,
      fill: type === "text" ? THEME.textPrimary : "rgba(34, 197, 94, 0.2)",
      stroke: type === "text" ? "transparent" : THEME.accentGreen,
      text: type === "text" ? "Label" : undefined
    }
    
    this.state.objects = [...(this.state.objects || []), base]
    this.scheduleRender(false)
  }
  
  createGroupFromSelection() {
    if (this.selectedSeats.size < 2) return
    
    this.state.groups = [
      ...(this.state.groups || []),
      {
        id: randomId("group"),
        name: `Group ${String((this.state.groups || []).length + 1).padStart(2, "0")}`,
        seat_slot_ids: Array.from(this.selectedSeats),
        color: THEME.accentGreen
      }
    ]
    this.scheduleRender(false)
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
    
    this.scheduleRender(false)
  }
  
  updateExportTarget(selectText = false) {
    const target = document.querySelector(`[data-seat-map-export-for="${this.el.id}"]`)
    if (!target) return
    
    target.value = JSON.stringify(this.serializableState(), null, 2)
    if (selectText) target.select()
  }
  
  serializableState() {
    return {
      ...this.state,
      revision: parseInt(this.state.revision, 10) || 1,
      seats: (this.state.seats || []).map((seat) => ({ ...seat })),
      objects: (this.state.objects || []).map((object) => ({ ...object })),
      groups: (this.state.groups || []).map((group) => ({ ...group }))
    }
  }
  
  scaleStage(nextScale) {
    const clampedScale = clamp(nextScale, 0.3, 4)
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
  
  viewportCenter() {
    const scale = this.stage.scaleX() || 1
    return {
      x: (this.stage.width() / 2 - this.stage.x()) / scale,
      y: (this.stage.height() / 2 - this.stage.y()) / scale
    }
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
    const clampedScale = clamp(nextScale, 0.3, 4)
    
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
      const center = { x: (pointOne.x + pointTwo.x) / 2, y: (pointOne.y + pointTwo.y) / 2 }
      const distance = Math.hypot(pointTwo.x - pointOne.x, pointTwo.y - pointOne.y)
      
      if (!this.lastTouchCenter) {
        this.lastTouchCenter = center
        this.lastTouchDistance = distance
        return
      }
      
      const scale = this.stage.scaleX() * (distance / this.lastTouchDistance)
      const clampedScale = clamp(scale, 0.3, 4)
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
    this.seatLayer.listening(false)
    this.objectLayer.listening(false)
  }
  
  handleDragEnd() {
    this.seatLayer.listening(true)
    this.objectLayer.listening(true)
    this.stage.batchDraw()
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
  
  transparentColor(hexColor, alpha) {
    const sanitized = (hexColor || "#22c55e").replace("#", "")
    const value = sanitized.length === 3 ? sanitized.split("").map((part) => `${part}${part}`).join("") : sanitized
    const red = parseInt(value.slice(0, 2), 16)
    const green = parseInt(value.slice(2, 4), 16)
    const blue = parseInt(value.slice(4, 6), 16)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
  }
}