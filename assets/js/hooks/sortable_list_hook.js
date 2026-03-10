/**
 * SortableListHook - Handles drag and drop reordering for list items.
 *
 * Usage: Add `phx-hook="SortableListHook"` to the container element.
 * Each sortable child should have a `data-id` attribute.
 * Drag handles within children should have the `[data-drag-handle]` attribute
 * and `draggable="true"`.
 *
 * On drop, pushes a "reorder" event with `{ ids: [...] }` containing
 * the new order of data-id values.
 */
const SortableListHook = {
  mounted() {
    this.setupDragAndDrop();
  },

  updated() {
    // Re-setup after LiveView patches the DOM
    this.setupDragAndDrop();
  },

  setupDragAndDrop() {
    const container = this.el;
    let draggedItem = null;

    // Clean up old listeners by replacing the container's event handling
    // (we use event delegation so this is safe)
    container.ondragstart = (e) => {
      const handle = e.target.closest('[data-drag-handle]');
      if (!handle) return;

      draggedItem = handle.closest('[data-id]');
      if (!draggedItem) return;

      draggedItem.classList.add('opacity-50');
      e.dataTransfer.effectAllowed = 'move';
      // Required for Firefox
      e.dataTransfer.setData('text/plain', '');
    };

    container.ondragend = () => {
      if (draggedItem) {
        draggedItem.classList.remove('opacity-50');
        draggedItem = null;
      }
      // Remove all drop indicators
      container.querySelectorAll('[data-id]').forEach(el => {
        el.classList.remove('border-t-2', 'border-b-2', 'border-primary');
      });
    };

    container.ondragover = (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';

      const target = e.target.closest('[data-id]');
      if (!target || target === draggedItem) return;

      // Clear previous indicators
      container.querySelectorAll('[data-id]').forEach(el => {
        el.classList.remove('border-t-2', 'border-b-2', 'border-primary');
      });

      // Show drop indicator based on cursor position
      const rect = target.getBoundingClientRect();
      const midY = rect.top + rect.height / 2;
      if (e.clientY < midY) {
        target.classList.add('border-t-2', 'border-primary');
      } else {
        target.classList.add('border-b-2', 'border-primary');
      }
    };

    container.ondragleave = (e) => {
      const target = e.target.closest('[data-id]');
      if (target) {
        target.classList.remove('border-t-2', 'border-b-2', 'border-primary');
      }
    };

    container.ondrop = (e) => {
      e.preventDefault();
      if (!draggedItem) return;

      const target = e.target.closest('[data-id]');
      if (!target || target === draggedItem) return;

      // Determine if we should insert before or after target
      const rect = target.getBoundingClientRect();
      const midY = rect.top + rect.height / 2;
      const insertBefore = e.clientY < midY;

      // Perform the DOM move
      if (insertBefore) {
        target.parentNode.insertBefore(draggedItem, target);
      } else {
        target.parentNode.insertBefore(draggedItem, target.nextSibling);
      }

      // Collect new order and push to LiveView
      const ids = Array.from(container.querySelectorAll('[data-id]'))
        .map(el => parseInt(el.dataset.id));

      this.pushEvent('reorder', { ids });

      // Cleanup
      draggedItem.classList.remove('opacity-50');
      draggedItem = null;
      container.querySelectorAll('[data-id]').forEach(el => {
        el.classList.remove('border-t-2', 'border-b-2', 'border-primary');
      });
    };
  }
};

export default SortableListHook;
