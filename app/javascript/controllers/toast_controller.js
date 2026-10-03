import { Controller } from "@hotwired/stimulus"

// XP and achievement toasts dismiss themselves.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 6000 } }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.remove()
  }
}
