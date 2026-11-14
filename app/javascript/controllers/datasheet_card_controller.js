import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "trigger", "panel" ]

  toggle() {
    const open = this.element.dataset.open !== "true"
    this.token = (this.token || 0) + 1
    this.element.dataset.open = String(open)

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(open))
      this.triggerTarget.setAttribute("aria-label", open ? "Ocultar secciones" : "Mostrar secciones")
    }

    if (open) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  expand() {
    const panel = this.panelTarget
    const token = this.token
    const target = this.measure(panel, "0px")

    panel.style.height = `${target}px`
    this.releaseHeight(panel, token)
  }

  collapse() {
    const panel = this.panelTarget
    this.measure(panel, `${panel.scrollHeight}px`)
    panel.style.height = "0px"
  }

  measure(panel, height) {
    panel.style.transition = "none"
    panel.style.height = height
    const target = panel.scrollHeight
    panel.offsetHeight
    panel.style.transition = ""
    return target
  }

  releaseHeight(panel, token) {
    const onEnd = (event) => {
      if (event.target !== panel || event.propertyName !== "height") return
      if (token === this.token && this.element.dataset.open === "true") panel.style.height = "auto"
      panel.removeEventListener("transitionend", onEnd)
    }

    panel.addEventListener("transitionend", onEnd)
  }
}
