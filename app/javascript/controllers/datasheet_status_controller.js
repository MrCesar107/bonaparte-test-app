import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  refresh() {
    if (!this.frame || !this.hasUrlValue) return

    if (this.frame.getAttribute("src")) {
      this.frame.reload()
    } else {
      this.frame.src = this.urlValue
    }
  }
}
