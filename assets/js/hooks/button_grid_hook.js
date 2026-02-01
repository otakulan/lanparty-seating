/**
 * ButtonGridHook - Handles drag and drop for station grid layout in settings page.
 * Allows reordering stations by dragging them to new positions.
 */
const ButtonGridHook = {
  mounted() {
    let draggedElement = null;
    const container = this.el;

    container.addEventListener('dragstart', event => {
      if (!event.target.matches('[station-x]')) return;
      draggedElement = event.target;
    });

    container.addEventListener("drop", event => {
      if (!event.target.matches('[station-x]')) return;
      if (!draggedElement) return;

      const from = {
        x: parseInt(draggedElement.getAttribute("station-x")),
        y: parseInt(draggedElement.getAttribute("station-y"))
      };
      const to = {
        x: parseInt(event.target.getAttribute("station-x")),
        y: parseInt(event.target.getAttribute("station-y"))
      };

      this.pushEvent("move", { from, to });
      draggedElement = null;
    });

    // Prevent default to allow drop
    container.addEventListener("dragover", event => {
      event.preventDefault();
    });
  }
};

export default ButtonGridHook;
