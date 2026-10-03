import { Controller } from "@hotwired/stimulus"

// Per-question timer for the interview pressure modes (spec 44).
export default class extends Controller {
  static targets = ["display"]
  static values = { seconds: Number, urgentAt: { type: Number, default: 15 } }

  connect() {
    if (!this.secondsValue || this.secondsValue <= 0) return
    this.remaining = this.secondsValue
    this.paint()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    this.remaining -= 1
    this.paint()
    if (this.remaining <= 0) {
      clearInterval(this.timer)
      // Time up submits whatever is written, as a real timed round would.
      this.element.closest("form")?.requestSubmit()
    }
  }

  paint() {
    const minutes = Math.floor(Math.max(this.remaining, 0) / 60)
    const seconds = Math.max(this.remaining, 0) % 60
    const text = `${minutes}:${String(seconds).padStart(2, "0")}`
    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = text
      this.displayTarget.classList.toggle("timer--urgent", this.remaining <= this.urgentAtValue)
    }
    this.element.setAttribute("aria-label", `${text} remaining`)
  }
}
