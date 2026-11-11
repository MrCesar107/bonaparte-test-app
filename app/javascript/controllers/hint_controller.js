import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tooltip" ]

  show() {
    this.tooltipTarget.classList.remove("hidden")
    this.tooltipTarget.setAttribute("aria-hidden", "false")
  }

  hide() {
    this.tooltipTarget.classList.add("hidden")
    this.tooltipTarget.setAttribute("aria-hidden", "true")
  }
}
