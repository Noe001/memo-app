import { Controller } from "@hotwired/stimulus"

// Handles sliding transition between default sidebar content and group create panel
// Expected structure:
// <div data-controller="group-create">
//   <div class="sidebar-content" data-group-create-target="content"> ... </div>
//   <div id="group-create-panel" class="sidebar-panel hidden-panel" data-group-create-target="panel"> ... </div>
// </div>
// The trigger button needs: data-action="click->group-create#open"
// The back/cancel button inside panel needs: data-action="click->group-create#close"
export default class extends Controller {
  static targets = ["content", "panel"]

  open(event) {
    event.preventDefault()
    // Slide existing content out to left
    this.contentTarget.classList.add("slide-out-left")
    // Show panel and slide in
    this.panelTarget.classList.remove("hidden-panel")
    this.panelTarget.classList.add("slide-in-right")
  }

  close(event) {
    if (event) event.preventDefault()
    // Reverse animations for content
    this.contentTarget.classList.remove("slide-out-left")
    this.contentTarget.style.visibility = "visible"
    // Slide panel back to right
    this.panelTarget.classList.remove("slide-in-right")
    this.panelTarget.classList.add("slide-out-right")

    // After transition ends, hide the panel and reset classes
    const onTransitionEnd = () => {
      this.panelTarget.classList.remove("slide-out-right")
      this.panelTarget.classList.add("hidden-panel")
      // ensure content is visible again
      this.contentTarget.style.visibility = "visible"
      this.panelTarget.removeEventListener("transitionend", onTransitionEnd)
    }
    this.panelTarget.addEventListener("transitionend", onTransitionEnd)
  }
}
