import { Controller } from "@hotwired/stimulus"

// Disables a submit button while a request is running, so a learner cannot
// queue five sandbox runs by double-clicking.
export default class extends Controller {
  static targets = ["button", "label"]
  static values = { busyLabel: { type: String, default: "Running…" } }

  start() {
    if (!this.hasButtonTarget) return
    this.original = this.hasLabelTarget ? this.labelTarget.textContent : this.buttonTarget.textContent
    this.buttonTarget.disabled = true
    this.buttonTarget.setAttribute("aria-busy", "true")
    if (this.hasLabelTarget) this.labelTarget.textContent = this.busyLabelValue
    else this.buttonTarget.textContent = this.busyLabelValue
  }

  // Turbo replaces the result frame on completion; this restores the button
  // when the form itself survives the response.
  finish() {
    if (!this.hasButtonTarget) return
    this.buttonTarget.disabled = false
    this.buttonTarget.removeAttribute("aria-busy")
    if (this.original) {
      if (this.hasLabelTarget) this.labelTarget.textContent = this.original
      else this.buttonTarget.textContent = this.original
    }
  }
}
