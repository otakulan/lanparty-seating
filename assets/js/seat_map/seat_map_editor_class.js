import Konva from "konva"
import {
  SeatMapBase,
  SCALE_BY,
  clamp,
  randomId,
  groupBounds,
  getClientRect,
  getTotalBox,
  rectsOverlap
} from "./seat_map_base"
import {
  SEAT_WIDTH,
  SEAT_HEIGHT,
  createEditorSeatGroup,
  createLockBadge
} from "./seat_map_renderer"
import { withAlpha } from "./seat_map_theme"

export const MIN_LABEL_WIDTH = 60
export const MIN_LABEL_HEIGHT = 32
export const MIN_LABEL_FONT_SIZE = 8
export const MAX_LABEL_FONT_SIZE = 160
export const DEFAULT_LABEL_FONT_SIZE = 18
export const LABEL_PADDING = 8
// The canvas rectangle can't be shrunk below this (content coordinates).
export const MIN_CANVAS_SIZE = 200
// While resizing, the canvas edge is blocked this far outside the content's
// bounding box, so shrinking never pushes the border into (or past) an object.
export const CANVAS_EDGE_BUFFER = 20

// Lucide icon paths (lucide.dev) for the context menu, inline so they inherit
// the button's `currentColor` (and turn red for the danger action).
const CONTEXT_MENU_ICONS = {
  edit: [
    "M12 20h-1a2 2 0 0 1-2-2 2 2 0 0 1-2 2H6",
    "M13 8h7a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-7",
    "M5 16H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h1",
    "M6 4h1a2 2 0 0 1 2 2 2 2 0 0 1 2-2h1",
    "M9 6v12"
  ],
  front: [
    "M5 3h14",
    "m18 13-6-6-6 6",
    "M12 7v14"
  ],
  back: [
    "M12 17V3",
    "m6 11 6 6 6-6",
    "M19 21H5"
  ],
  lock: [
    "M5 11 H19 a2 2 0 0 1 2 2 V20 a2 2 0 0 1 -2 2 H5 a2 2 0 0 1 -2 -2 V13 a2 2 0 0 1 2 -2 Z",
    "M7 11 V7 a5 5 0 0 1 10 0 v4"
  ],
  unlock: [
    "M5 11 H19 a2 2 0 0 1 2 2 V20 a2 2 0 0 1 -2 2 H5 a2 2 0 0 1 -2 -2 V13 a2 2 0 0 1 2 -2 Z",
    "M7 11 V7 a5 5 0 0 1 9.9 -1"
  ],
  trash: [
    "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6",
    "M3 6h18",
    "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
  ]
}

function createContextMenuIcon(name, danger = false) {
  const ns = "http://www.w3.org/2000/svg"
  const svg = document.createElementNS(ns, "svg")
  svg.setAttribute("viewBox", "0 0 24 24")
  svg.setAttribute("width", "16")
  svg.setAttribute("height", "16")
  svg.setAttribute("fill", "none")
  svg.setAttribute("stroke", "currentColor")
  svg.setAttribute("stroke-width", "2")
  svg.setAttribute("stroke-linecap", "round")
  svg.setAttribute("stroke-linejoin", "round")
  svg.classList.add("shrink-0")

  for (const d of CONTEXT_MENU_ICONS[name] || []) {
    const path = document.createElementNS(ns, "path")
    path.setAttribute("d", d)
    svg.appendChild(path)
  }

  return svg
}

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
    this.dragLayer = null
    this.commandsBound = false
    this.contextMenu = null
    this.labelEditor = null
    this.editingObjectId = null
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
    
    // The label editor textarea and the context menu are positioned inside the
    // stage container, so it has to establish a containing block.
    if (getComputedStyle(this.stageContainer).position === "static") {
      this.stageContainer.style.position = "relative"
    }
    
    this.stage = new Konva.Stage({
      container: this.stageContainer,
      width: this.stageContainer.clientWidth,
      height: this.stageContainer.clientHeight,
      draggable: false
    })
    
    this.seatLayer = new Konva.Layer()
    this.objectLayer = new Konva.Layer()
    this.objectLayerFront = new Konva.Layer()
    this.dragLayer = new Konva.Layer()
    // The shared base methods (renderGroups / renderTeamLabels) draw into
    // `groupLayer` (behind everything) and `overlayLayer` (in front). Alias them
    // onto the existing object layers so the stage stays within Konva's
    // recommended layer count instead of adding two more layers.
    this.groupLayer = this.objectLayer
    this.overlayLayer = this.objectLayerFront
    
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
        const scale = this.stage.scaleX() || 1
        const minSize = this.transformerMinSize()

        if (Math.abs(newBox.width) < minSize.width * scale ||
            Math.abs(newBox.height) < minSize.height * scale) {
          return oldBox
        }

        // Transformer boxes are in absolute (screen) coordinates; map the box
        // corners back into canvas (content) coordinates with the stage's own
        // inverse transform so rotation and zoom are handled correctly. Clamp
        // each edge independently to the canvas so resizing stops cleanly at the
        // boundary without ever overflowing it.
        const toContent = this.stage.getAbsoluteTransform().copy().invert()
        const toScreen = this.stage.getAbsoluteTransform()
        const tl = toContent.point({ x: newBox.x, y: newBox.y })
        const br = toContent.point({ x: newBox.x + newBox.width, y: newBox.y + newBox.height })
        const left = Math.min(tl.x, br.x)
        const top = Math.min(tl.y, br.y)
        const right = Math.max(tl.x, br.x)
        const bottom = Math.max(tl.y, br.y)

        const cLeft = clamp(left, 0, this.state.width)
        const cTop = clamp(top, 0, this.state.height)
        const cRight = clamp(right, 0, this.state.width)
        const cBottom = clamp(bottom, 0, this.state.height)

        // Degenerate (inverted) box after clamping: reject rather than produce
        // something invalid.
        if (cRight - cLeft < minSize.width / scale ||
            cBottom - cTop < minSize.height / scale) {
          return oldBox
        }

        const newTl = toScreen.point({ x: cLeft, y: cTop })
        const newBr = toScreen.point({ x: cRight, y: cBottom })
        return {
          x: newTl.x,
          y: newTl.y,
          width: newBr.x - newTl.x,
          height: newBr.y - newTl.y,
          rotation: newBox.rotation
        }
      }
    })
    
    // The transformer lives above every layer so its anchors are never covered.
    this.dragLayer.add(this.transformer)
    
    // Objects sit on two layers: tables behind the seats (furniture must never
    // cover a seat and steal its clicks), labels in front so they stay selectable
    // and editable. Either can be moved to the other layer via Bring to front /
    // Send to back.
    this.stage.add(this.objectLayer)
    this.stage.add(this.seatLayer)
    this.stage.add(this.objectLayerFront)
    this.stage.add(this.dragLayer)
    
    this.stage.on("wheel", e => this.handleWheel(e))
    this.stage.on("touchmove", e => this.handleTouchMove(e))
    this.stage.on("touchend", () => this.handleTouchEnd())
    this.stage.on("click tap", e => this.handleStageClick(e))
    this.stage.on("contextmenu", e => this.handleContextMenu(e))
    this.stage.on("mousedown", () => this.stageContainer.focus())
    this.stage.on("dragmove", () => this.constrainStageDrag())
    this.stage.on("dragstart", () => this.setCursor("grabbing"))
    this.stage.on("dragend", () => this.setCursor("default"))
    
    this.stage.on("mousedown", e => {
      if (e.evt.altKey && !this.canvasFitsInViewport()) {
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
      if (e.key === "Alt" && !this.canvasFitsInViewport()) this.stage.draggable(true)
      if (e.key === "Escape") {
        this.hideContextMenu()
        this.clearSelection()
      }
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
    
    this.setupContextMenuDismissal()
    this.setupResizeHandler()
  }
  
  bindCommands() {
    if (this.commandsBound) return
    this.commandsBound = true
    
    this.handleCommandClick = e => {
      const button = e.target.closest("[data-seat-map-command]")
      if (!button || !this.el.contains(button)) return
      e.preventDefault()
      this.executeCommand(button.dataset.seatMapCommand)
    }
    this.el.addEventListener("click", this.handleCommandClick)
  }
  
  destroy() {
    if (this.handleCommandClick) this.el.removeEventListener("click", this.handleCommandClick)
    this.commandsBound = false
    this.cancelLabelEdit()
    this.hideContextMenu()
    this.teardownContextMenuDismissal()
    this.teardownResizeHandler()
    if (this.keyHandler) {
      this.stageContainer.removeEventListener("keydown", this.keyHandler.keydown)
      this.stageContainer.removeEventListener("keyup", this.keyHandler.keyup)
    }
    if (this.renderFrame) cancelAnimationFrame(this.renderFrame)
    if (this._recacheTimer) clearTimeout(this._recacheTimer)
    super.destroy()
  }
  
  renderScene(resetView) {
    // Detach the transformer first: destroyChildren() would destroy it along with
    // its anchors, and a destroyed transformer throws on the next update().
    this.transformer.remove()
    
    this.seatLayer.destroyChildren()
    this.objectLayer.destroyChildren()
    this.objectLayerFront.destroyChildren()
    this.dragLayer.destroyChildren()
    
    this.dragLayer.add(this.transformer)
    
    this.renderCanvasBounds()
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
  
  // Drag and resize are clamped to the canvas rect, so it has to be visible.
  // Everything here lives on the front overlay layer so the frame and its resize
  // handle stay grabbable above the seats/objects.
  renderCanvasBounds() {
    const theme = this.theme
    const layer = this.overlayLayer

    this.canvasBorderRect = new Konva.Rect({
      x: 0,
      y: 0,
      width: this.state.width,
      height: this.state.height,
      // base-content, not base-300: base-300 is nearly the background color on
      // both light and dark themes.
      stroke: withAlpha(theme.textPrimary, 0.45),
      strokeWidth: 2,
      dash: [12, 8],
      listening: false,
      perfectDrawEnabled: false,
      shadowForStrokeEnabled: false
    })
    layer.add(this.canvasBorderRect)

    this.canvasBoundaryLabel = new Konva.Text({
      text: "Room boundary",
      x: this.state.width / 2,
      y: 8,
      fontSize: 14,
      fontFamily: theme.fontFamily,
      fontStyle: "600",
      fill: withAlpha(theme.textPrimary, 0.5),
      listening: false,
      perfectDrawEnabled: false
    })
    this.canvasBoundaryLabel.offsetX(this.canvasBoundaryLabel.width() / 2)
    layer.add(this.canvasBoundaryLabel)

    const handleSize = 16
    this.canvasResizeHandle = new Konva.Rect({
      x: this.state.width,
      y: this.state.height,
      width: handleSize,
      height: handleSize,
      offsetX: handleSize / 2,
      offsetY: handleSize / 2,
      fill: theme.accentCyan,
      cornerRadius: 4,
      draggable: true,
      perfectDrawEnabled: false
    })
    this.canvasResizeHandle.on("mouseenter", () => this.setCursor("nwse-resize"))
    this.canvasResizeHandle.on("mouseleave", () => this.setCursor("default"))
    this.canvasResizeHandle.on("dragstart", () => {
      this.pushHistory()
      this.setCursor("nwse-resize")
    })
    this.canvasResizeHandle.on("dragmove", () => this.resizeCanvasToHandle())
    this.canvasResizeHandle.on("dragend", () => {
      this.setCursor("default")
      this.scheduleRender(false)
    })
    layer.add(this.canvasResizeHandle)
  }

  // The smallest the canvas may be shrunk to: the content's bounding box plus a
  // buffer, so the border stops before reaching any seat or object. Computed
  // per axis from the rightmost/bottommost content extent (the top-left stays
  // anchored at the canvas origin).
  minCanvasSizeForContent(buffer = CANVAS_EDGE_BUFFER) {
    let maxX = 0
    let maxY = 0

    for (const seat of this.state.seats) {
      maxX = Math.max(maxX, seat.x + seat.width / 2)
      maxY = Math.max(maxY, seat.y + seat.height / 2)
    }
    for (const object of this.state.objects) {
      maxX = Math.max(maxX, object.x + object.width)
      maxY = Math.max(maxY, object.y + object.height)
    }

    return {
      width: Math.max(MIN_CANVAS_SIZE, Math.ceil(maxX) + buffer),
      height: Math.max(MIN_CANVAS_SIZE, Math.ceil(maxY) + buffer)
    }
  }

  // The resize handle sits at the canvas corner; its position in content
  // coordinates is the new canvas size. Update the border and label live so the
  // frame follows the pointer without a full scene rebuild (which would destroy
  // the handle mid-drag).
  resizeCanvasToHandle() {
    const handle = this.canvasResizeHandle
    if (!handle) return

    // The border can't cross into the buffer zone around content: block the
    // resize at the content's bounding box plus CANVAS_EDGE_BUFFER on each axis.
    const minSize = this.minCanvasSizeForContent()

    let newWidth = Math.round(handle.x())
    let newHeight = Math.round(handle.y())

    if (newWidth < minSize.width) {
      newWidth = minSize.width
      handle.x(newWidth)
    }
    if (newHeight < minSize.height) {
      newHeight = minSize.height
      handle.y(newHeight)
    }

    this.state.width = newWidth
    this.state.height = newHeight

    if (this.canvasBorderRect) {
      this.canvasBorderRect.size({ width: newWidth, height: newHeight })
    }
    if (this.canvasBoundaryLabel) {
      this.canvasBoundaryLabel.x(newWidth / 2)
      this.canvasBoundaryLabel.offsetX(this.canvasBoundaryLabel.width() / 2)
    }
    this.overlayLayer.batchDraw()
  }
  
  renderObjects() {
    const theme = this.theme
    
    for (const object of this.state.objects) {
      const id = object.id
      const isText = object.type === "text"
      const isLocked = object.locked === true
      let node
      
      if (isText) {
        node = new Konva.Text({
          x: object.x,
          y: object.y,
          width: object.width,
          height: object.height,
          rotation: object.rotation,
          text: object.text,
          fontSize: object.font_size || DEFAULT_LABEL_FONT_SIZE,
          fontStyle: "600",
          fontFamily: theme.fontFamily,
          fill: object.fill,
          padding: LABEL_PADDING,
          verticalAlign: "middle",
          perfectDrawEnabled: false
        })
      } else {
        node = new Konva.Rect({
          x: object.x,
          y: object.y,
          width: object.width,
          height: object.height,
          rotation: object.rotation,
          fill: object.fill,
          stroke: object.stroke,
          strokeWidth: 2,
          cornerRadius: 12,
          shadowColor: withAlpha(object.stroke || theme.tableStroke, 0.3),
          shadowBlur: 16,
          shadowOpacity: 0.6,
          perfectDrawEnabled: false
        })
      }
      
      node.id(id)
      node.setAttr("nodeType", "object")
      node.setAttr("objectId", id)
      node.draggable(!isLocked)
      
      node.on("click tap", e => this.handleObjectSelection(e, node))
      node.on("mouseenter", () => this.setCursor(isLocked ? "not-allowed" : "grab"))
      node.on("mouseleave", () => this.setCursor("default"))
      node.on("dragstart", () => {
        this.pushHistory()
        this.selectObjectForDrag(id)
      })
      node.on("dragmove", () => this.constrainObjectDrag(node))
      node.on("dragend transformend", () => this.syncObjectNode(node))
      
      if (isText) {
        node.on("dblclick dbltap", event => {
          event.cancelBubble = true
          this.startLabelEdit(id)
        })
        node.on("transform", () => this.resizeLabelNode(node))
      }
      
       this.layerForObject(object).add(node)
       node.cache({ pixelRatio: this.cachePixelRatio() })
       
       if (this.editingObjectId === id) node.hide()
       if (isLocked) this.addObjectLockBadge(object)
     }
     
     this.syncTransformer()
   }
   
   layerForObject(object) {
     return object.front === true ? this.objectLayerFront : this.objectLayer
   }
   
   objectLayers() {
     return [this.objectLayer, this.objectLayerFront]
   }
   
    batchDrawObjectLayers() {
      this.objectLayer.batchDraw()
      this.objectLayerFront.batchDraw()
    }

    // Cached nodes are rasterized at this pixel ratio so they stay crisp at the
    // current zoom level (clamped to the max zoom to bound memory).
    cachePixelRatio() {
      return clamp(this.stage.scaleX() || 1, 1, this.getMaxScale())
    }

    // Re-rasterize every cached node at the current zoom after a zoom gesture
    // settles, so shapes stay sharp without paying the vector cost per frame.
    recacheScene() {
      const pixelRatio = this.cachePixelRatio()

      this.seatLayer.getChildren().forEach(seatGroup => {
        const body = seatGroup.findOne(".seat-body")
        if (body) body.cache({ pixelRatio })
      })

      this.objectLayers().forEach(layer => {
        layer.getChildren().forEach(node => {
          if (node.getAttr("nodeType") === "object") node.cache({ pixelRatio })
        })
      })

      this.seatLayer.batchDraw()
      this.batchDrawObjectLayers()
    }

    scheduleRecache() {
      if (this._recacheTimer) clearTimeout(this._recacheTimer)
      this._recacheTimer = setTimeout(() => {
        this._recacheTimer = null
        if (this.editingObjectId) return
        this.recacheScene()
      }, 150)
    }

   addObjectLockBadge(object) {
     const holder = new Konva.Group({
       x: object.x,
       y: object.y,
       rotation: object.rotation,
       listening: false
     })
     holder.add(createLockBadge(this.theme, { x: object.width - 12, y: 12 }))
     this.layerForObject(object).add(holder)
   }
   
   findObjectNode(objectId) {
     return this.objectLayers()
       .flatMap(layer => layer.children)
       .find(node => node.getAttr("objectId") === objectId)
   }
  
  // Dragging an unselected object selects it. No scheduleRender here: re-rendering
  // would destroy the node the pointer is currently dragging.
  selectObjectForDrag(objectId) {
    if (this.selectedObjects.has(objectId)) return
    
    const hadSeats = this.selectedSeats.size > 0
    this.selectedSeats.clear()
    this.selectedObjects = new Set([objectId])
    this.syncTransformer()
    this.batchDrawObjectLayers()
    if (hadSeats) this.hook.pushEvent("seat_selected", { seat: null })
  }
  
  // Keeps the transformer attached to the current selection. Locked objects and
  // the label being edited are never transformable.
  syncTransformer() {
    const nodes = []
    
    for (const objectId of this.selectedObjects) {
      const object = this.state.objects.find(o => o.id === objectId)
      if (!object || object.locked || this.editingObjectId === objectId) continue
      const node = this.findObjectNode(objectId)
      if (node) nodes.push(node)
    }
    
    this.transformer.nodes(nodes)
    this.transformer.visible(nodes.length > 0)
    this.transformer.moveToTop()
    this.dragLayer.batchDraw()
  }
  
  transformerMinSize() {
    const isLabelOnly = this.transformer.nodes().every(node => node.getClassName() === "Text")
    
    return isLabelOnly
      ? { width: MIN_LABEL_WIDTH, height: MIN_LABEL_HEIGHT }
      : { width: SEAT_WIDTH, height: SEAT_HEIGHT }
  }
  
  setCursor(cursor) {
    this.stageContainer.style.cursor = cursor
  }
   
  getGroupLayer() {
    return this.groupLayer
  }
  
  renderSeats() {
    const theme = this.theme
    const statusColors = this.statusColors
    
    for (const seat of this.state.seats) {
      const palette = statusColors[seat.status] || statusColors.available
      const isSelected = this.selectedSeats.has(seat.seat_slot_id)
      const isLocked = seat.locked === true
      
      const seatGroup = createEditorSeatGroup(seat, palette, theme, {
        showKeyboard: this.showKeyboard,
        isSelected,
        isLocked,
        cacheBody: true,
        cachePixelRatio: this.cachePixelRatio()
      })
      
      seatGroup.id(`seat-${seat.seat_slot_id}`)
      seatGroup.draggable(!isLocked)
      
      seatGroup.on("click tap", e => this.handleSeatClick(e, seat))
      seatGroup.on("mouseenter", () => this.setCursor(isLocked ? "not-allowed" : "grab"))
      seatGroup.on("mouseleave", () => this.setCursor("default"))
      seatGroup.on("dragstart", () => {
        this.pushHistory()
        // Dragging an unselected seat selects it. No scheduleRender here: it would
        // destroy the node the pointer is dragging, the highlight lands on dragend.
        if (!this.selectedSeats.has(seat.seat_slot_id)) {
          this.selectedSeats = new Set([seat.seat_slot_id])
          this.selectedObjects.clear()
          this.transformer.nodes([])
          this.transformer.visible(false)
        }
        seatGroup.moveTo(this.dragLayer)
        
        if (this.selectedSeats.size > 1) {
          this.dragStartPosition = { x: seatGroup.x(), y: seatGroup.y() }
          this.draggedSeatId = seat.seat_slot_id
        } else {
          this.hook.pushEvent("seat_selected", { seat })
        }
      })
      seatGroup.on("dragmove", () => {
        this.constrainNodeDrag(seatGroup, SEAT_WIDTH, SEAT_HEIGHT)
        const constrained = this.constrainSeatCollision(
          seatGroup.x(), seatGroup.y(),
          SEAT_WIDTH, SEAT_HEIGHT,
          seat.seat_slot_id
        )
        seatGroup.position(constrained)
        if (this.selectedSeats.size > 1 && this.dragStartPosition && this.draggedSeatId === seat.seat_slot_id) {
          const dx = constrained.x - this.dragStartPosition.x
          const dy = constrained.y - this.dragStartPosition.y
          const movedPositions = this.moveSelectedSeats(dx, dy, seat.seat_slot_id)
          this.constrainMultiSeatCollision(movedPositions, seat.seat_slot_id)
        }
      })
      seatGroup.on("dragend", () => {
        seatGroup.moveTo(this.seatLayer)
        this.syncSeatNode(seatGroup, seat.seat_slot_id)
        if (this.selectedSeats.size > 1 && this.draggedSeatId === seat.seat_slot_id) {
          this.syncAllSelectedSeats()
        }
        this.dragStartPosition = null
        this.draggedSeatId = null
        this.seatLayer.batchDraw()
      })
      
      this.seatLayer.add(seatGroup)
    }
  }
  
  moveSelectedSeats(dx, dy, excludeSeatId) {
    const positions = new Map()
    this.selectedSeats.forEach(seatSlotId => {
      if (seatSlotId === excludeSeatId) return
      const node = this.seatLayer.children.find(n => n.id() === `seat-${seatSlotId}`)
      if (!node) return
      const seat = this.state.seats.find(s => s.seat_slot_id === seatSlotId)
      if (!seat || seat.locked) return
      const newX = seat.x + dx
      const newY = seat.y + dy
      node.x(newX)
      node.y(newY)
      positions.set(seatSlotId, { x: newX, y: newY, node })
    })
    this.seatLayer.batchDraw()
    return positions
  }
  
  constrainMultiSeatCollision(positions, leadSeatId) {
    let minDx = 0
    let minDy = 0
    
    for (const [seatSlotId, pos] of positions) {
      const seat = this.state.seats.find(s => s.seat_slot_id === seatSlotId)
      if (!seat) continue
      
      const constrained = this.constrainSeatCollision(
        pos.x, pos.y,
        seat.width, seat.height,
        seatSlotId
      )
      
      const dx = constrained.x - pos.x
      const dy = constrained.y - pos.y
      
      if (Math.abs(dx) > Math.abs(minDx)) minDx = dx
      if (Math.abs(dy) > Math.abs(minDy)) minDy = dy
    }
    
    if (minDx !== 0 || minDy !== 0) {
      for (const [seatSlotId, pos] of positions) {
        pos.node.x(pos.x + minDx)
        pos.node.y(pos.y + minDy)
      }
      const leadNode = this.seatLayer.children.find(n => n.id() === `seat-${leadSeatId}`)
      if (leadNode) {
        leadNode.x(leadNode.x() + minDx)
        leadNode.y(leadNode.y() + minDy)
      }
    }
  }
  
  syncAllSelectedSeats() {
    this.selectedSeats.forEach(seatSlotId => {
      const node = this.seatLayer.children.find(n => n.id() === `seat-${seatSlotId}`)
      if (node) this.syncSeatNode(node, seatSlotId)
    })
  }
  
  handleStageClick(event) {
    if (event.evt?.button === 2) return
    
    // A click always leaves a marquee rect behind (any pixel of movement creates
    // one). Only a real marquee drag consumes the click, otherwise deselection
    // would never happen.
    if (this.marqueeRect) {
      const wasMarqueeDrag = this.marqueeRect.width() > 5 && this.marqueeRect.height() > 5
      
      this.marqueeRect.destroy()
      this.marqueeRect = null
      this.overlayLayer.batchDraw()
      this.isMarqueeActive = false
      
      if (wasMarqueeDrag) return
    }
    
    // A click on a seat or object is handled by its own handler; only an empty
    // canvas click should clear the selection.
    const target = this.resolveNodeTarget(event.target)
    if (target) return

    if (event.target === this.stage) this.clearSelection()
  }
  
  handleSeatClick(event, seat) {
    event.cancelBubble = true
    // Right-click selection is owned by the context menu handler
    if (event.evt?.button === 2) return
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
      const selectedSeat = this.state.seats.find(s => s.seat_slot_id === seat.seat_slot_id)
      if (selectedSeat) this.hook.pushEvent("seat_selected", { seat: selectedSeat })
    } else {
      this.hook.pushEvent("seat_selected", { seat: null })
    }
  }
  
  // Objects are anchored top-left (unlike seats, which are centered), so clamp
  // their real bounding box - rotation included - inside the canvas.
  constrainObjectDrag(node) {
    // Use the node's own layer as the coordinate origin: it is always an
    // ancestor, so getClientRect returns content coordinates. Relative to a
    // fixed layer (e.g. objectLayer) only yields content coords while the node
    // is a descendant of it - after Bring to front the node lives on
    // objectLayerFront, so the box would come back in screen coords and the
    // clamp would silently stop constraining it.
    const box = node.getClientRect({
      relativeTo: node.getLayer(),
      skipShadow: true,
      skipStroke: true
    })
    
    const dx = clamp(box.x, 0, Math.max(0, this.state.width - box.width)) - box.x
    const dy = clamp(box.y, 0, Math.max(0, this.state.height - box.height)) - box.y
    
    if (dx !== 0 || dy !== 0) node.position({ x: node.x() + dx, y: node.y() + dy })
  }
  
  constrainNodeDrag(node, nodeWidth, nodeHeight) {
    const canvasWidth = this.state.width
    const canvasHeight = this.state.height
    const halfW = nodeWidth / 2
    const halfH = nodeHeight / 2
    
    node.position({
      x: clamp(node.x(), halfW, canvasWidth - halfW),
      y: clamp(node.y(), halfH, canvasHeight - halfH)
    })
  }
  
  constrainSeatCollision(newX, newY, width, height, excludeId) {
    const halfW = width / 2
    const halfH = height / 2
    const draggedRect = {
      x: newX - halfW,
      y: newY - halfH,
      width: width,
      height: height
    }
    
    for (const seat of this.state.seats) {
      if (seat.seat_slot_id === excludeId) continue
      if (this.selectedSeats.has(seat.seat_slot_id)) continue
      
      const seatW = seat.width
      const seatH = seat.height
      const seatHalfW = seatW / 2
      const seatHalfH = seatH / 2
      const seatRect = {
        x: seat.x - seatHalfW,
        y: seat.y - seatHalfH,
        width: seatW,
        height: seatH
      }
      
      if (rectsOverlap(draggedRect, seatRect)) {
        const overlapLeft = draggedRect.x + draggedRect.width - seatRect.x
        const overlapRight = seatRect.x + seatRect.width - draggedRect.x
        const overlapTop = draggedRect.y + draggedRect.height - seatRect.y
        const overlapBottom = seatRect.y + seatRect.height - draggedRect.y
        
        const minOverlapX = Math.min(overlapLeft, overlapRight)
        const minOverlapY = Math.min(overlapTop, overlapBottom)
        
        if (minOverlapX < minOverlapY) {
          if (overlapLeft < overlapRight) {
            newX = seatRect.x - halfW - 1
          } else {
            newX = seatRect.x + seatRect.width + halfW + 1
          }
          draggedRect.x = newX - halfW
        } else {
          if (overlapTop < overlapBottom) {
            newY = seatRect.y - halfH - 1
          } else {
            newY = seatRect.y + seatRect.height + halfH + 1
          }
          draggedRect.y = newY - halfH
        }
      }
    }
    
    return { x: newX, y: newY }
  }
  
  handleObjectSelection(event, node) {
    event.cancelBubble = true
    // Right-click selection is owned by the context menu handler
    if (event.evt?.button === 2) return
    this.stageContainer.focus()
    
    const isMultiSelect = event.evt.shiftKey || event.evt.ctrlKey || event.evt.metaKey
    const objectId = node.getAttr("objectId")
    const hadSeats = this.selectedSeats.size > 0
    
    if (isMultiSelect) {
      if (this.selectedObjects.has(objectId)) {
        this.selectedObjects.delete(objectId)
      } else {
        this.selectedObjects.add(objectId)
      }
      this.selectedSeats.clear()
    } else {
      this.selectedObjects = new Set([objectId])
      this.selectedSeats.clear()
    }
    
    this.syncTransformer()
    this.batchDrawObjectLayers()
    
    // Repaint so seat highlights drop, and drop the seat details panel with them
    if (hadSeats) {
      this.hook.pushEvent("seat_selected", { seat: null })
      this.scheduleRender(false)
    }
  }
  
  syncObjectNode(node) {
    const objectId = node.getAttr("objectId")
    const isText = node.getClassName() === "Text"
    const minWidth = isText ? MIN_LABEL_WIDTH : SEAT_WIDTH
    const minHeight = isText ? MIN_LABEL_HEIGHT : SEAT_HEIGHT
    
    const scaleX = node.scaleX()
    const scaleY = node.scaleY()

    this.state.objects = this.state.objects.map(obj => {
      if (obj.id !== objectId) return obj

      const next = {
        ...obj,
        x: Math.round(node.x()),
        y: Math.round(node.y()),
        width: Math.max(minWidth, Math.round(node.width() * scaleX)),
        height: Math.max(minHeight, Math.round(node.height() * scaleY)),
        rotation: Math.round(node.rotation())
      }

      if (isText) next.font_size = Math.round(node.fontSize())
      return next
    })

    // Bake the transformer's scale into the node's own size immediately so the
    // live node keeps its resized look for the frame before scheduleRender
    // rebuilds it. Without this it collapses to the pre-resize size and flashes.
    node.scaleX(1)
    node.scaleY(1)
    node.width(Math.max(minWidth, Math.round(node.width() * scaleX)))
    node.height(Math.max(minHeight, Math.round(node.height() * scaleY)))
    // The cache was rasterized at the pre-resize geometry, so its bitmap and its
    // internal offset no longer match the resized node - leaving a ghost of the
    // old shape for a frame. Re-rasterize at the new geometry so the transitional
    // frame draws correctly. A plain drag only translates the node, which keeps
    // the cache valid, so skip this unless the transform actually scaled it.
    if (scaleX !== 1 || scaleY !== 1) {
      if (node.isCached()) node.clearCache()
      node.cache({ pixelRatio: this.cachePixelRatio() })
    }
    node.getLayer()?.batchDraw()
    this.scheduleRender(false)
  }
  
  // Labels resize like a text box: keep scale at 1 and grow the font so the
  // wrapped text fills the new height.
  resizeLabelNode(node) {
    const width = Math.max(MIN_LABEL_WIDTH, node.width() * node.scaleX())
    const height = Math.max(MIN_LABEL_HEIGHT, node.height() * node.scaleY())
    
    node.setAttrs({
      width,
      height,
      scaleX: 1,
      scaleY: 1,
      fontSize: this.fitFontSize(node.text(), width, height)
    })
  }
  
  // Largest font size whose wrapped text still fits the box height.
  fitFontSize(text, width, height) {
    const probe = new Konva.Text({
      text: text || " ",
      width,
      padding: LABEL_PADDING,
      fontFamily: this.theme.fontFamily,
      fontStyle: "600",
      fontSize: DEFAULT_LABEL_FONT_SIZE
    })
    
    let low = MIN_LABEL_FONT_SIZE
    let high = MAX_LABEL_FONT_SIZE
    let best = MIN_LABEL_FONT_SIZE
    
    while (low <= high) {
      const candidate = Math.floor((low + high) / 2)
      probe.fontSize(candidate)
      
      if (probe.height() <= height) {
        best = candidate
        low = candidate + 1
      } else {
        high = candidate - 1
      }
    }
    
    probe.destroy()
    return best
  }
  
  measureTextWidth(text, fontSize) {
    const probe = new Konva.Text({
      text: text || " ",
      fontFamily: this.theme.fontFamily,
      fontStyle: "600",
      fontSize
    })
    const width = probe.width()
    probe.destroy()
    return width
  }
  
  syncSeatNode(node, seatSlotId) {
    this.state.seats = this.state.seats.map(seat => {
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
    const hadSeats = this.selectedSeats.size > 0
    
    this.selectedSeats.clear()
    this.selectedObjects.clear()
    this.transformer.nodes([])
    this.transformer.visible(false)
    this.scheduleRender(false)
    
    if (hadSeats) this.hook.pushEvent("seat_selected", { seat: null })
  }
  
  selectedItems() {
    const seats = Array.from(this.selectedSeats)
      .map(id => this.state.seats.find(seat => seat.seat_slot_id === id))
      .filter(Boolean)
    const objects = Array.from(this.selectedObjects)
      .map(id => this.state.objects.find(object => object.id === id))
      .filter(Boolean)
    
    return [...seats, ...objects]
  }
  
  hasSelection() {
    return this.selectedSeats.size > 0 || this.selectedObjects.size > 0
  }
  
  selectionIsLocked() {
    const items = this.selectedItems()
    return items.length > 0 && items.every(item => item.locked === true)
  }
  
  toggleLock() {
    this.setSelectionLocked(!this.selectionIsLocked())
  }
  
  // Lock is editor-authoring metadata: locked nodes cannot be dragged or resized.
  // Applies to the whole current selection (seats and objects).
  setSelectionLocked(locked) {
    if (!this.hasSelection()) return
    
    this.pushHistory()
    this.state.seats = this.state.seats.map(seat =>
      this.selectedSeats.has(seat.seat_slot_id) ? { ...seat, locked } : seat
    )
    this.state.objects = this.state.objects.map(object =>
      this.selectedObjects.has(object.id) ? { ...object, locked } : object
    )
    this.scheduleRender(false)
  }
  
  // Move the selection to the front or back layer. The layer is the z-order and
  // persists with the map data via the `front` flag.
  setObjectsFront(front) {
    if (this.selectedObjects.size === 0) return

    this.pushHistory()
    this.state.objects = this.state.objects.map(object =>
      this.selectedObjects.has(object.id) ? { ...object, front } : object
    )
    this.scheduleRender(false)
  }
  
  resolveNodeTarget(target) {
    let node = target
    
    while (node && node !== this.stage) {
      const nodeType = node.getAttr?.("nodeType")
      if (nodeType === "seat") return { type: "seat", id: node.getAttr("seatSlotId") }
      if (nodeType === "object") return { type: "object", id: node.getAttr("objectId") }
      node = node.parent
    }
    
    return null
  }
  
  handleContextMenu(event) {
    event.evt.preventDefault()
    this.stageContainer.focus()
    this.finishLabelEdit(true)
    
    const target = this.resolveNodeTarget(event.target)
    
    if (!target) {
      this.hideContextMenu()
      this.clearSelection()
      return
    }
    
    // Right-clicking inside the selection keeps it, otherwise the item becomes
    // the whole selection.
    const isSelected = target.type === "seat"
      ? this.selectedSeats.has(target.id)
      : this.selectedObjects.has(target.id)
    
    if (!isSelected) {
      this.selectedSeats = new Set(target.type === "seat" ? [target.id] : [])
      this.selectedObjects = new Set(target.type === "object" ? [target.id] : [])
      this.syncTransformer()
      this.scheduleRender(false)
    }
    
    this.showContextMenu(this.stage.getPointerPosition())
  }
  
  contextMenuItems() {
    if (!this.hasSelection()) return []
    
    const items = []
    const [onlyObject] = this.selectedObjects.size === 1 && this.selectedSeats.size === 0
      ? this.selectedItems()
      : []

    if (onlyObject && onlyObject.type === "text" && !onlyObject.locked) {
      items.push({
        label: "Edit text",
        icon: "edit",
        action: () => this.startLabelEdit(onlyObject.id)
      })
    }

    if (this.selectedObjects.size > 0) {
      items.push({
        label: "Bring to front",
        icon: "front",
        action: () => this.setObjectsFront(true)
      })
      items.push({
        label: "Send to back",
        icon: "back",
        action: () => this.setObjectsFront(false)
      })
    }

    items.push({
      label: this.selectionIsLocked() ? "Unlock" : "Lock",
      icon: this.selectionIsLocked() ? "unlock" : "lock",
      action: () => this.toggleLock()
    })

    items.push({
      label: "Delete",
      icon: "trash",
      danger: true,
      action: () => this.deleteSelection()
    })

    return items
  }

  showContextMenu(position) {
    this.hideContextMenu()

    const items = this.contextMenuItems()
    if (items.length === 0 || !position) return

    const menu = document.createElement("ul")
    menu.className =
      "menu menu-sm absolute z-30 w-max rounded-box border border-base-300 bg-base-200 p-1 shadow-xl"
    menu.style.position = "absolute"
    menu.style.left = `${position.x}px`
    menu.style.top = `${position.y}px`

    for (const item of items) {
      const entry = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      if (item.danger) button.className = "text-error"

      if (item.icon) {
        button.appendChild(createContextMenuIcon(item.icon, item.danger))
      }

      const label = document.createElement("span")
      label.textContent = item.label
      button.appendChild(label)

      button.addEventListener("click", () => {
        this.hideContextMenu()
        item.action()
      })
      entry.appendChild(button)
      menu.appendChild(entry)
    }

    this.stageContainer.appendChild(menu)
    this.contextMenu = menu

    const overflowX = position.x + menu.offsetWidth - this.stageContainer.clientWidth
    const overflowY = position.y + menu.offsetHeight - this.stageContainer.clientHeight
    if (overflowX > 0) menu.style.left = `${Math.max(0, position.x - menu.offsetWidth)}px`
    if (overflowY > 0) menu.style.top = `${Math.max(0, position.y - menu.offsetHeight)}px`
  }
  
  hideContextMenu() {
    if (!this.contextMenu) return
    this.contextMenu.remove()
    this.contextMenu = null
  }
  
  setupContextMenuDismissal() {
    this.teardownContextMenuDismissal()
    
    this.contextMenuDismiss = event => {
      if (this.contextMenu && this.contextMenu.contains(event.target)) return
      this.hideContextMenu()
    }
    this.contextMenuKeydown = event => {
      if (event.key === "Escape") this.hideContextMenu()
    }
    
    document.addEventListener("mousedown", this.contextMenuDismiss, true)
    document.addEventListener("keydown", this.contextMenuKeydown, true)
    window.addEventListener("scroll", this.contextMenuDismiss, true)
    window.addEventListener("wheel", this.contextMenuDismiss, true)
  }
  
  teardownContextMenuDismissal() {
    if (!this.contextMenuDismiss) return
    
    document.removeEventListener("mousedown", this.contextMenuDismiss, true)
    document.removeEventListener("keydown", this.contextMenuKeydown, true)
    window.removeEventListener("scroll", this.contextMenuDismiss, true)
    window.removeEventListener("wheel", this.contextMenuDismiss, true)
    this.contextMenuDismiss = null
    this.contextMenuKeydown = null
  }
  
  // Inline label editing: the Konva text node is hidden and a textarea is
  // overlaid on the canvas at the node's screen position.
  startLabelEdit(objectId) {
    const object = this.state.objects.find(o => o.id === objectId && o.type === "text")
    if (!object || object.locked) return
    
    this.finishLabelEdit(true)
    this.hideContextMenu()
    
    const node = this.findObjectNode(objectId)
    if (!node) return
    
    this.editingObjectId = objectId
    this.selectedSeats.clear()
    this.selectedObjects = new Set([objectId])
    node.hide()
    this.transformer.nodes([])
    this.transformer.visible(false)
    this.batchDrawObjectLayers()
    this.dragLayer.batchDraw()
    
    const textarea = this.buildLabelTextarea(node)
    this.stageContainer.appendChild(textarea)
    this.labelEditor = { textarea, objectId }
    
    textarea.focus()
    textarea.select()
  }
  
  buildLabelTextarea(node) {
    const theme = this.theme
    const scale = this.stage.scaleX()
    const textarea = document.createElement("textarea")
    
    textarea.value = node.text()
    textarea.style.position = "absolute"
    textarea.style.left = `${node.x() * scale + this.stage.x()}px`
    textarea.style.top = `${node.y() * scale + this.stage.y()}px`
    textarea.style.width = `${node.width() * scale}px`
    textarea.style.height = `${node.height() * scale}px`
    textarea.style.padding = `${LABEL_PADDING * scale}px`
    textarea.style.margin = "0"
    textarea.style.border = `2px solid ${theme.accentCyan}`
    textarea.style.borderRadius = "6px"
    textarea.style.background = theme.background
    textarea.style.color = node.fill()
    textarea.style.fontSize = `${node.fontSize() * scale}px`
    textarea.style.fontFamily = node.fontFamily()
    textarea.style.fontWeight = "600"
    textarea.style.lineHeight = String(node.lineHeight())
    textarea.style.textAlign = node.align()
    textarea.style.boxSizing = "border-box"
    textarea.style.overflow = "hidden"
    textarea.style.outline = "none"
    textarea.style.resize = "none"
    textarea.style.zIndex = "20"
    textarea.style.transformOrigin = "left top"
    textarea.style.transform = `rotateZ(${node.rotation()}deg)`
    
    textarea.addEventListener("keydown", event => {
      event.stopPropagation()
      
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault()
        this.finishLabelEdit(true)
      } else if (event.key === "Escape") {
        event.preventDefault()
        this.finishLabelEdit(false)
      }
    })
    
    // Clicking away commits the text and leaves the label deselected.
    textarea.addEventListener("blur", () => this.finishLabelEdit(true, { deselect: true }))
    
    return textarea
  }
  
  finishLabelEdit(commit, options = {}) {
    const editor = this.labelEditor
    if (!editor) return
    
    this.labelEditor = null
    this.editingObjectId = null
    
    const value = editor.textarea.value
    editor.textarea.remove()
    
    if (commit) this.applyLabelText(editor.objectId, value)
    
    if (options.deselect) {
      this.selectedSeats.clear()
      this.selectedObjects.clear()
    }
    
    this.scheduleRender(false)
  }
  
  cancelLabelEdit() {
    this.finishLabelEdit(false)
  }
  
  applyLabelText(objectId, value) {
    const object = this.state.objects.find(o => o.id === objectId)
    if (!object) return
    
    // An empty label would be invisible and impossible to click again.
    const text = value.trim() === "" ? "Label" : value
    if (text === object.text) return
    
    this.pushHistory()
    
    const fontSize = object.font_size || DEFAULT_LABEL_FONT_SIZE
    const naturalWidth = Math.ceil(this.measureTextWidth(text, fontSize)) + LABEL_PADDING * 2
    const width = clamp(
      Math.max(object.width, naturalWidth, MIN_LABEL_WIDTH),
      MIN_LABEL_WIDTH,
      this.state.width
    )
    
    this.state.objects = this.state.objects.map(o =>
      o.id === objectId ? { ...o, text, width } : o
    )
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
        fill: withAlpha(theme.accentCyan, 0.15),
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
    
    for (const seat of this.state.seats) {
      const halfW = seat.width / 2
      const halfH = seat.height / 2
      const seatRect = {
        x: seat.x - halfW,
        y: seat.y - halfH,
        width: halfW * 2,
        height: halfH * 2
      }
      
      if (rectsOverlap(rect, seatRect)) {
        if (isCtrlOrMeta && this.selectedSeats.has(seat.seat_slot_id)) {
          this.selectedSeats.delete(seat.seat_slot_id)
        } else {
          this.selectedSeats.add(seat.seat_slot_id)
        }
      }
    }
    
    for (const obj of this.state.objects) {
      const objRect = {
        x: obj.x,
        y: obj.y,
        width: obj.width,
        height: obj.height
      }
      
      if (rectsOverlap(rect, objRect)) {
        if (isCtrlOrMeta && this.selectedObjects.has(obj.id)) {
          this.selectedObjects.delete(obj.id)
        } else {
          this.selectedObjects.add(obj.id)
        }
      }
    }
    
    this.syncTransformer()
    this.scheduleRender(false)
  }
  
  pushHistory() {
    if (this.isUndoRedo) return
    
    const state = JSON.stringify({
      seats: this.state.seats,
      objects: this.state.objects,
      groups: this.state.groups
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
    
    this.cancelLabelEdit()
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
      ...this.state.seats,
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
        reservation_end_date: null,
        locked: false
      }
    ]
    this.scheduleRender(false)
  }
  
  addObject(type) {
    this.pushHistory()
    const theme = this.theme
    // Place at the canvas center, not the viewport center: when the canvas is
    // larger than the viewport and panned, the viewport center maps to a point
    // near a canvas edge, leaving no room to resize toward that edge.
    const isText = type === "text"
    const id = randomId(type)
    const halfW = isText ? 90 : 60
    const halfH = isText ? 20 : 32
    const point = { x: this.state.width / 2, y: this.state.height / 2 }

    this.state.objects = [
      ...this.state.objects,
      {
        id,
        type,
        x: Math.round(point.x - halfW),
        y: Math.round(point.y - halfH),
        width: isText ? 180 : 120,
        height: isText ? 40 : 64,
        rotation: 0,
        // null (not undefined) so JSON keeps the keys the server normalizer expects
        font_size: isText ? DEFAULT_LABEL_FONT_SIZE : null,
        fill: isText ? theme.textPrimary : theme.tableFill,
        fill_secondary: null,
        stroke: isText ? "transparent" : theme.tableStroke,
        text: isText ? "Label" : null,
        locked: false,
        // Labels default to the front layer so they stay selectable/editable on
        // top of seats; tables default behind.
        front: isText ? true : false
      }
    ]

    this.ensureCanvasCenterVisible()

    if (!isText) {
      const hadSeats = this.selectedSeats.size > 0
      this.selectedSeats.clear()
      this.selectedObjects = new Set([id])
      if (hadSeats) this.hook.pushEvent("seat_selected", { seat: null })
      this.scheduleRender(false)
      return
    }

    // New labels open straight into the inline editor, so render synchronously
    // to get a node to attach the textarea to.
    this.selectedSeats.clear()
    this.selectedObjects = new Set([id])
    if (this.renderFrame) {
      cancelAnimationFrame(this.renderFrame)
      this.renderFrame = null
    }
    this.renderScene(false)
    this.startLabelEdit(id)
  }

  // Recenter the view on the canvas center only if it isn't already visible, so
  // a freshly added object has room to resize in every direction without
  // yanking the user's pan when they're already looking at the middle.
  ensureCanvasCenterVisible() {
    const scale = this.stage.scaleX() || 1
    const cx = this.state.width / 2 * scale + this.stage.x()
    const cy = this.state.height / 2 * scale + this.stage.y()
    const margin = 40
    const visible =
      cx >= margin && cx <= this.stage.width() - margin &&
      cy >= margin && cy <= this.stage.height() - margin

    if (!visible) this.centerCanvas()
  }
  
  createGroupFromSelection() {
    if (this.selectedSeats.size < 2) return
    
    this.pushHistory()
    const theme = this.theme
    this.state.groups = [
      ...this.state.groups,
      {
        id: randomId("group"),
        name: `Group ${String(this.state.groups.length + 1).padStart(2, "0")}`,
        seat_slot_ids: Array.from(this.selectedSeats),
        color: theme.accentGreen
      }
    ]
    this.scheduleRender(false)
  }
  
  deleteSelection() {
    this.cancelLabelEdit()
    this.pushHistory()
    
    if (this.selectedSeats.size > 0) {
      const selectedIds = this.selectedSeats
      this.state.seats = this.state.seats.filter(s => !selectedIds.has(s.seat_slot_id))
      this.state.groups = this.state.groups.map(g => ({
        ...g,
        seat_slot_ids: g.seat_slot_ids.filter(id => !selectedIds.has(id))
      }))
      this.selectedSeats.clear()
    }
    
    if (this.selectedObjects.size > 0) {
      const selectedIds = this.selectedObjects
      this.state.objects = this.state.objects.filter(o => !selectedIds.has(o.id))
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
      revision: this.state.revision,
      seats: this.state.seats.map(s => ({ ...s })),
      objects: this.state.objects.map(o => ({ ...o })),
      groups: this.state.groups.map(g => ({ ...g }))
    }
  }
  
  fitToStage(resetPosition) {
    super.fitToStage(resetPosition)
    this.scheduleRecache()
  }
  
  // Editing happens inside the canvas rect, so it stays part of the viewport
  // instead of fitting the seats only.
  getContentBounds() {
    const content = super.getContentBounds()
    const minX = Math.min(0, content.x)
    const minY = Math.min(0, content.y)
    const maxX = Math.max(this.state.width, content.x + content.width)
    const maxY = Math.max(this.state.height, content.y + content.height)
    
    return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
  }
  
  viewportCenter() {
    const scale = this.stage.scaleX()
    return {
      x: (this.stage.width() / 2 - this.stage.x()) / scale,
      y: (this.stage.height() / 2 - this.stage.y()) / scale
    }
  }
  
  getMaxScale() {
    return 4
  }
  
  handleWheel(event) {
    this.hideContextMenu()
    super.handleWheel(event)
    this.scheduleRecache()
  }
  
  handleTouchMove(event) {
    super.handleTouchMove(event)
    // Re-enable panning after touch gesture in editor (Alt+drag for pan)
    this.stage.draggable(true)
  }
  
  handleTouchEnd() {
    super.handleTouchEnd()
    this.stage.draggable(true)
  }
  
  nextSeatId() {
    const ids = this.state.seats.map(s => Number(s.seat_slot_id) || 0)
    return Math.max(0, ...ids) + 1
  }
  
  nextSeatLabel() {
    const labels = new Set(this.state.seats.map(s => s.label))
    for (let row = 0; row < 26; row++) {
      const prefix = String.fromCharCode(65 + row)
      for (let col = 1; col <= 99; col++) {
        const label = `${prefix}${String(col).padStart(2, "0")}`
        if (!labels.has(label)) return label
      }
    }
    return `Z${String(this.state.seats.length + 1).padStart(2, "0")}`
  }
}