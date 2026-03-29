import Konva from "konva"
import {
  SeatMapBase,
  SCALE_BY,
  clamp,
  randomId,
  groupBounds,
  getClientRect,
  getTotalBox
} from "./seat_map_base"
import {
  SEAT_WIDTH,
  SEAT_HEIGHT,
  createEditorSeatGroup,
  renderGroupBounds,
  renderGroupLabel,
  renderTeamLabel,
  transparentColor
} from "./seat_map_renderer"

export default class SeatMapEditor extends SeatMapBase {
  constructor(hook, options = {}) {
    super(hook, options)
    this.showKeyboard = options.showKeyboard !== false
    this.selectedSeats = new Set()
    this.selectedObjects = new Set()
    this.history = []
    this.historyIndex = -1
    this.isUndoRedo = false
    this.isMarqueeActive = false
    this.marqueeStartPos = null
    this.lastSelectionModifier = null
    this.dragStartPosition = null
    this.draggedSeatId = null
  }
  
  mount() {
    this.buildStage()
    this.bindCommands()
    this.setupThemeListener()
    this.pushHistory()
    this.renderScene(true)
    this.stageContainer.focus()
  }
  
  buildStage() {
    const theme = this.theme
    
    this.stage = new Konva.Stage({
      container: this.stageContainer,
      width: this.stageContainer.clientWidth,
      height: this.stageContainer.clientHeight,
      draggable: false
    })
    
    this.groupLayer = new Konva.Layer({ listening: false })
    this.seatLayer = new Konva.Layer()
    this.objectLayer = new Konva.Layer()
    this.overlayLayer = new Konva.Layer({ listening: false })
    
    this.transformer = new Konva.Transformer({
      rotateEnabled: true,
      borderStroke: theme.accentCyan,
      anchorStroke: theme.accentCyan,
      anchorFill: theme.accentGreen,
      anchorSize: 8,
      anchorCornerRadius: 3,
      visible: false,
      ignoreStroke: true,
      boundBoxFunc: (oldBox, newBox) => {
        const box = getClientRect(newBox)
        const canvasWidth = this.state.width || 1920
        const canvasHeight = this.state.height || 1080
        
        if (box.x < 0 || box.y < 0 || 
            box.x + box.width > canvasWidth || 
            box.y + box.height > canvasHeight) {
          return oldBox
        }
        return newBox
      }
    })
    
    this.objectLayer.add(this.transformer)
    
    this.transformer.on("dragmove", () => {
      const nodes = this.transformer.nodes()
      if (nodes.length === 0) return
      
      const canvasWidth = this.state.width || 1920
      const canvasHeight = this.state.height || 1080
      const boxes = nodes.map(n => n.getClientRect())
      const box = getTotalBox(boxes)
      
      nodes.forEach(node => {
        const absPos = node.getAbsolutePosition()
        const offsetX = box.x - absPos.x
        const offsetY = box.y - absPos.y
        const newAbsPos = { ...absPos }
        
        if (box.x < 0) newAbsPos.x = -offsetX
        if (box.y < 0) newAbsPos.y = -offsetY
        if (box.x + box.width > canvasWidth) newAbsPos.x = canvasWidth - box.width - offsetX
        if (box.y + box.height > canvasHeight) newAbsPos.y = canvasHeight - box.height - offsetY
        
        node.setAbsolutePosition(newAbsPos)
      })
    })
    
    this.stage.add(this.groupLayer)
    this.stage.add(this.seatLayer)
    this.stage.add(this.objectLayer)
    this.stage.add(this.overlayLayer)
    
    this.stage.on("wheel", e => this.handleWheel(e))
    this.stage.on("touchmove", e => this.handleTouchMove(e))
    this.stage.on("touchend", () => this.handleTouchEnd())
    this.stage.on("click tap", e => this.handleStageClick(e))
    this.stage.on("mousedown", () => this.stageContainer.focus())
    this.stage.on("dragmove", () => this.constrainStageDrag())
    
    this.stage.on("mousedown", e => {
      if (e.evt.altKey) {
        this.isPanning = true
        this.stage.draggable(true)
        return
      }
      
      if (e.target === this.stage && e.evt.button === 0) {
        this.isMarqueeActive = true
        this.lastSelectionModifier = e.evt.ctrlKey ? 'ctrl' : e.evt.metaKey ? 'meta' : e.evt.shiftKey ? 'shift' : null
        const pos = this.stage.getPointerPosition()
        this.marqueeStartPos = pos
        this.marqueeStartPosTransformed = pos ? {
          x: (pos.x - this.stage.x()) / this.stage.scaleX(),
          y: (pos.y - this.stage.y()) / this.stage.scaleY()
        } : null
      }
    })
    
    this.stage.on("mousemove", e => {
      if (this.isMarqueeActive && this.marqueeStartPos && e.target === this.stage) {
        this.handleMarqueeMove(e)
      }
    })
    
    this.stage.on("mouseup mouseleave", () => {
      if (this.isMarqueeActive) this.handleMarqueeEnd()
      this.isMarqueeActive = false
      if (this.isPanning) {
        this.isPanning = false
        this.stage.draggable(false)
      }
    })
    
    const handleKeyDown = e => {
      if (e.key === "Alt") this.stage.draggable(true)
      if (e.key === "Escape") this.clearSelection()
      if ((e.key === "Delete" || e.key === "Backspace") && !e.target.closest('input, textarea')) {
        if (this.selectedSeats.size > 0 || this.selectedObjects.size > 0) {
          e.preventDefault()
          this.deleteSelection()
        }
      }
      if ((e.ctrlKey || e.metaKey) && e.key === "z" && !e.target.closest('input, textarea')) {
        e.preventDefault()
        e.shiftKey ? this.redo() : this.undo()
      }
      if ((e.ctrlKey || e.metaKey) && e.key === "y" && !e.target.closest('input, textarea')) {
        e.preventDefault()
        this.redo()
      }
    }
    
    const handleKeyUp = e => {
      if (e.key === "Alt") this.stage.draggable(false)
    }
    
    this.stageContainer.addEventListener("keydown", handleKeyDown)
    this.stageContainer.addEventListener("keyup", handleKeyUp)
    this.keyHandler = { keydown: handleKeyDown, keyup: handleKeyUp }
    
    this.handleResize = () => {
      this.stage.width(this.stageContainer.clientWidth)
      this.stage.height(this.stageContainer.clientHeight)
      this.fitToStage(true)
    }
    window.addEventListener("resize", this.handleResize)
  }
  
  bindCommands() {
    this.handleCommandClick = e => {
      const button = e.target.closest("[data-seat-map-command]")
      if (!button || !this.el.contains(button)) return
      e.preventDefault()
      this.executeCommand(button.dataset.seatMapCommand)
    }
    this.el.addEventListener("click", this.handleCommandClick)
  }
  
  destroy() {
    this.el.removeEventListener("click", this.handleCommandClick)
    window.removeEventListener("resize", this.handleResize)
    if (this.keyHandler) {
      this.stageContainer.removeEventListener("keydown", this.keyHandler.keydown)
      this.stageContainer.removeEventListener("keyup", this.keyHandler.keyup)
    }
    if (this.renderFrame) cancelAnimationFrame(this.renderFrame)
    super.destroy()
  }
  
  renderScene(resetView) {
    this.groupLayer.destroyChildren()
    this.seatLayer.destroyChildren()
    this.objectLayer.destroyChildren()
    this.overlayLayer.destroyChildren()
    
    this.objectLayer.add(this.transformer)
    
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
  
  renderObjects() {
    const theme = this.theme
    
    for (const object of this.state.objects || []) {
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
          fontFamily: theme.fontFamily,
          fill: object.fill || theme.textPrimary,
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
          stroke: object.stroke || theme.accentGreen,
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
      
      node.on("click tap", e => this.handleObjectSelection(e, node))
      node.on("dragstart", () => this.pushHistory())
      node.on("dragmove", () => {
        const w = isText ? (object.width || 180) : (object.width || 120)
        const h = isText ? (object.height || 36) : (object.height || 60)
        this.constrainNodeDrag(node, w, h)
      })
      node.on("dragend transformend", () => this.syncObjectNode(node))
      
      this.objectLayer.add(node)
    }
  }
  
  renderGroups() {
    const theme = this.theme
    const groups = this.state.groups || []
    const seats = this.state.seats || []
    const teamAssignments = this.state.team_assignments || []
    
    for (const group of groups) {
      renderGroupBounds(this.groupLayer, group, seats, theme)
      renderGroupLabel(this.groupLayer, group, seats, teamAssignments, theme)
    }
  }
  
  renderSeats() {
    const theme = this.theme
    const statusColors = this.statusColors
    
    for (const seat of this.state.seats || []) {
      const palette = statusColors[seat.status] || statusColors.available
      const isSelected = this.selectedSeats.has(seat.seat_slot_id)
      
      const seatGroup = createEditorSeatGroup(seat, palette, theme, {
        showKeyboard: this.showKeyboard,
        isSelected
      })
      
      seatGroup.id(`seat-${seat.seat_slot_id}`)
      seatGroup.draggable(true)
      
      seatGroup.on("click tap", e => this.handleSeatClick(e, seat))
      seatGroup.on("dragstart", () => {
        this.pushHistory()
        if (this.selectedSeats.size > 1 && this.selectedSeats.has(seat.seat_slot_id)) {
          this.dragStartPosition = { x: seatGroup.x(), y: seatGroup.y() }
          this.draggedSeatId = seat.seat_slot_id
        }
      })
      seatGroup.on("dragmove", () => {
        this.constrainNodeDrag(seatGroup, SEAT_WIDTH, SEAT_HEIGHT)
        if (this.selectedSeats.size > 1 && this.dragStartPosition && this.draggedSeatId === seat.seat_slot_id) {
          const dx = seatGroup.x() - this.dragStartPosition.x
          const dy = seatGroup.y() - this.dragStartPosition.y
          this.moveSelectedSeats(dx, dy, seat.seat_slot_id)
        }
      })
      seatGroup.on("dragend", () => {
        this.syncSeatNode(seatGroup, seat.seat_slot_id)
        if (this.selectedSeats.size > 1 && this.draggedSeatId === seat.seat_slot_id) {
          this.syncAllSelectedSeats()
        }
        this.dragStartPosition = null
        this.draggedSeatId = null
      })
      
      this.seatLayer.add(seatGroup)
    }
  }
  
  moveSelectedSeats(dx, dy, excludeSeatId) {
    this.selectedSeats.forEach(seatSlotId => {
      if (seatSlotId === excludeSeatId) return
      const node = this.seatLayer.children.find(n => n.id() === `seat-${seatSlotId}`)
      if (!node) return
      const seat = (this.state.seats || []).find(s => s.seat_slot_id === seatSlotId)
      if (!seat) return
      node.x(seat.x + dx)
      node.y(seat.y + dy)
    })
    this.seatLayer.batchDraw()
  }
  
  syncAllSelectedSeats() {
    this.selectedSeats.forEach(seatSlotId => {
      const node = this.seatLayer.children.find(n => n.id() === `seat-${seatSlotId}`)
      if (node) this.syncSeatNode(node, seatSlotId)
    })
  }
  
  renderTeamLabels() {
    const theme = this.theme
    const groups = this.state.groups || []
    const seats = this.state.seats || []
    
    for (const assignment of this.state.team_assignments || []) {
      renderTeamLabel(this.overlayLayer, assignment, groups, seats, theme)
    }
  }
  
  handleStageClick(event) {
    if (this.marqueeRect && this.marqueeRect.width() > 5 && this.marqueeRect.height() > 5) return
    
    if (this.marqueeRect) {
      this.marqueeRect.destroy()
      this.marqueeRect = null
      this.overlayLayer.batchDraw()
      this.isMarqueeActive = false
      return
    }
    
    if (event.target === this.stage) this.clearSelection()
  }
  
  handleSeatClick(event, seat) {
    event.cancelBubble = true
    this.stageContainer.focus()
    
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
    
    if (this.selectedSeats.size === 1) {
      const selectedSeat = (this.state.seats || []).find(s => s.seat_slot_id === seat.seat_slot_id)
      if (selectedSeat) this.hook.pushEvent("seat_selected", { seat: selectedSeat })
    } else {
      this.hook.pushEvent("seat_selected", { seat: null })
    }
  }
  
  constrainStageDrag() {
    const scale = this.stage.scaleX() || 1
    const canvasWidth = this.state.width || 1920
    const canvasHeight = this.state.height || 1080
    const stageWidth = this.stage.width()
    const stageHeight = this.stage.height()
    
    const scaledWidth = canvasWidth * scale
    const scaledHeight = canvasHeight * scale
    
    let newX = this.stage.x()
    let newY = this.stage.y()
    
    if (scaledWidth <= stageWidth) {
      newX = (stageWidth - scaledWidth) / 2
    } else {
      newX = clamp(newX, stageWidth - scaledWidth, 0)
    }
    
    if (scaledHeight <= stageHeight) {
      newY = (stageHeight - scaledHeight) / 2
    } else {
      newY = clamp(newY, stageHeight - scaledHeight, 0)
    }
    
    this.stage.position({ x: newX, y: newY })
  }
  
  constrainNodeDrag(node, nodeWidth, nodeHeight) {
    const canvasWidth = this.state.width || 1920
    const canvasHeight = this.state.height || 1080
    const halfW = (nodeWidth || 64) / 2
    const halfH = (nodeHeight || 64) / 2
    
    node.position({
      x: clamp(node.x(), halfW, canvasWidth - halfW),
      y: clamp(node.y(), halfH, canvasHeight - halfH)
    })
  }
  
  handleObjectSelection(event, node) {
    event.cancelBubble = true
    this.stageContainer.focus()
    
    const isMultiSelect = event.evt.shiftKey || event.evt.ctrlKey || event.evt.metaKey
    const objectId = node.getAttr("objectId")
    
    if (isMultiSelect) {
      if (this.selectedObjects.has(objectId)) {
        this.selectedObjects.delete(objectId)
        this.transformer.nodes(this.transformer.nodes().filter(n => n !== node))
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
    this.state.objects = (this.state.objects || []).map(obj => {
      if (obj.id !== objectId) return obj
      return {
        ...obj,
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
    this.state.seats = (this.state.seats || []).map(seat => {
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
  
  handleMarqueeMove(event) {
    if (!this.isMarqueeActive) return
    
    const theme = this.theme
    const pos = this.stage.getPointerPosition()
    if (!pos) return
    
    const currentPos = {
      x: (pos.x - this.stage.x()) / this.stage.scaleX(),
      y: (pos.y - this.stage.y()) / this.stage.scaleY()
    }
    
    if (!this.marqueeRect) {
      this.marqueeRect = new Konva.Rect({
        fill: "rgba(6, 182, 212, 0.15)",
        stroke: theme.accentCyan,
        strokeWidth: 2,
        dash: [4, 4],
        listening: false
      })
      this.overlayLayer.add(this.marqueeRect)
    }
    
    const startPos = this.marqueeStartPosTransformed || currentPos
    this.marqueeRect.setAttrs({
      x: Math.min(startPos.x, currentPos.x),
      y: Math.min(startPos.y, currentPos.y),
      width: Math.abs(currentPos.x - startPos.x),
      height: Math.abs(currentPos.y - startPos.y)
    })
    this.overlayLayer.batchDraw()
  }
  
  handleMarqueeEnd() {
    if (!this.isMarqueeActive) return
    this.isMarqueeActive = false
    
    if (this.marqueeRect) {
      const marqueeBox = {
        x: this.marqueeRect.x(),
        y: this.marqueeRect.y(),
        width: this.marqueeRect.width(),
        height: this.marqueeRect.height()
      }
      
      setTimeout(() => {
        if (this.marqueeRect) {
          this.marqueeRect.destroy()
          this.marqueeRect = null
          this.overlayLayer.batchDraw()
        }
      })
      
      if (marqueeBox.width > 5 && marqueeBox.height > 5) {
        this.selectItemsInRect(marqueeBox)
      }
    }
    
    this.marqueeStartPos = null
    this.marqueeStartPosTransformed = null
    this.lastSelectionModifier = null
  }
  
  selectItemsInRect(rect) {
    const isCtrlOrMeta = this.lastSelectionModifier === 'ctrl' || this.lastSelectionModifier === 'meta'
    
    if (!isCtrlOrMeta) {
      this.selectedSeats.clear()
      this.selectedObjects.clear()
    }
    
    for (const seat of this.state.seats || []) {
      const halfW = (seat.width || 64) / 2
      const halfH = (seat.height || 64) / 2
      const seatRect = {
        x: seat.x - halfW,
        y: seat.y - halfH,
        width: halfW * 2,
        height: halfH * 2
      }
      
      if (this.rectanglesIntersect(rect, seatRect)) {
        if (isCtrlOrMeta && this.selectedSeats.has(seat.seat_slot_id)) {
          this.selectedSeats.delete(seat.seat_slot_id)
        } else {
          this.selectedSeats.add(seat.seat_slot_id)
        }
      }
    }
    
    const nodesToSelect = []
    for (const obj of this.state.objects || []) {
      const objRect = {
        x: obj.x,
        y: obj.y,
        width: obj.width || 100,
        height: obj.height || 60
      }
      
      if (this.rectanglesIntersect(rect, objRect)) {
        if (isCtrlOrMeta && this.selectedObjects.has(obj.id)) {
          this.selectedObjects.delete(obj.id)
        } else {
          this.selectedObjects.add(obj.id)
          const node = this.objectLayer.children.find(n => n.getAttr("objectId") === obj.id)
          if (node) nodesToSelect.push(node)
        }
      }
    }
    
    this.transformer.nodes(nodesToSelect)
    this.transformer.visible(nodesToSelect.length > 0)
    this.scheduleRender(false)
  }
  
  rectanglesIntersect(a, b) {
    return !(a.x + a.width < b.x || b.x + b.width < a.x ||
             a.y + a.height < b.y || b.y + b.height < a.y)
  }
  
  pushHistory() {
    if (this.isUndoRedo) return
    
    const state = JSON.stringify({
      seats: this.state.seats || [],
      objects: this.state.objects || [],
      groups: this.state.groups || []
    })
    
    if (this.historyIndex < this.history.length - 1) {
      this.history = this.history.slice(0, this.historyIndex + 1)
    }
    
    this.history.push(state)
    this.historyIndex = this.history.length - 1
    
    if (this.history.length > 100) {
      this.history.shift()
      this.historyIndex -= 1
    }
  }
  
  canUndo() { return this.historyIndex > 0 }
  canRedo() { return this.historyIndex < this.history.length - 1 }
  
  undo() {
    if (!this.canUndo()) return
    this.historyIndex -= 1
    this.restoreFromHistory()
  }
  
  redo() {
    if (!this.canRedo()) return
    this.historyIndex += 1
    this.restoreFromHistory()
  }
  
  restoreFromHistory() {
    const state = JSON.parse(this.history[this.historyIndex])
    
    this.isUndoRedo = true
    this.state.seats = state.seats
    this.state.objects = state.objects
    this.state.groups = state.groups
    this.selectedSeats.clear()
    this.selectedObjects.clear()
    this.transformer.nodes([])
    this.transformer.visible(false)
    this.scheduleRender(false)
    this.isUndoRedo = false
  }
  
  executeCommand(command) {
    switch (command) {
      case "zoom-in": this.scaleStage(this.stage.scaleX() * SCALE_BY); break
      case "zoom-out": this.scaleStage(this.stage.scaleX() / SCALE_BY); break
      case "reset-view": this.fitToStage(true); break
      case "add-seat": this.addSeatAtViewportCenter(); break
      case "add-table": this.addObject("rect"); break
      case "add-label": this.addObject("text"); break
      case "group-selection": this.createGroupFromSelection(); break
      case "delete-selection": this.deleteSelection(); break
      case "undo": this.undo(); break
      case "redo": this.redo(); break
      case "export-json": this.updateExportTarget(true); break
      case "save-draft": this.hook.pushEvent("save_draft_preview", { map: this.serializableState() }); break
      case "publish-preview": this.hook.pushEvent("publish_preview", { map: this.serializableState() }); break
    }
  }
  
  addSeatAtViewportCenter() {
    this.pushHistory()
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
    this.pushHistory()
    const theme = this.theme
    const point = this.viewportCenter()
    
    this.state.objects = [
      ...(this.state.objects || []),
      {
        id: randomId(type),
        type,
        x: Math.round(point.x - 60),
        y: Math.round(point.y - 30),
        width: type === "text" ? 180 : 120,
        height: type === "text" ? 36 : 60,
        rotation: 0,
        fill: type === "text" ? theme.textPrimary : "rgba(34, 197, 94, 0.2)",
        stroke: type === "text" ? "transparent" : theme.accentGreen,
        text: type === "text" ? "Label" : undefined
      }
    ]
    this.scheduleRender(false)
  }
  
  createGroupFromSelection() {
    if (this.selectedSeats.size < 2) return
    
    this.pushHistory()
    const theme = this.theme
    this.state.groups = [
      ...(this.state.groups || []),
      {
        id: randomId("group"),
        name: `Group ${String((this.state.groups || []).length + 1).padStart(2, "0")}`,
        seat_slot_ids: Array.from(this.selectedSeats),
        color: theme.accentGreen
      }
    ]
    this.scheduleRender(false)
  }
  
  deleteSelection() {
    this.pushHistory()
    
    if (this.selectedSeats.size > 0) {
      const selectedIds = this.selectedSeats
      this.state.seats = (this.state.seats || []).filter(s => !selectedIds.has(s.seat_slot_id))
      this.state.groups = (this.state.groups || []).map(g => ({
        ...g,
        seat_slot_ids: (g.seat_slot_ids || []).filter(id => !selectedIds.has(id))
      }))
      this.selectedSeats.clear()
    }
    
    if (this.selectedObjects.size > 0) {
      const selectedIds = this.selectedObjects
      this.state.objects = (this.state.objects || []).filter(o => !selectedIds.has(o.id))
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
      seats: (this.state.seats || []).map(s => ({ ...s })),
      objects: (this.state.objects || []).map(o => ({ ...o })),
      groups: (this.state.groups || []).map(g => ({ ...g }))
    }
  }
  
  scaleStage(nextScale) {
    const clampedScale = clamp(nextScale, 0.3, 4)
    const center = { x: this.stage.width() / 2, y: this.stage.height() / 2 }
    const oldScale = this.stage.scaleX() || 1
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
    
    this.constrainStageDrag()
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
  
  nextSeatId() {
    const ids = (this.state.seats || []).map(s => Number(s.seat_slot_id) || 0)
    return Math.max(0, ...ids) + 1
  }
  
  nextSeatLabel() {
    const labels = new Set((this.state.seats || []).map(s => s.label))
    for (let row = 0; row < 26; row++) {
      const prefix = String.fromCharCode(65 + row)
      for (let col = 1; col <= 99; col++) {
        const label = `${prefix}${String(col).padStart(2, "0")}`
        if (!labels.has(label)) return label
      }
    }
    return `Z${String((this.state.seats || []).length + 1).padStart(2, "0")}`
  }
}