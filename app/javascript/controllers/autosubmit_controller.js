import { Controller } from "@hotwired/stimulus"

// Debounced form submission for search and filter controls.
export default class extends Controller {
  static values = { delay: { type: Number, default: 350 } }

  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
