import { Controller } from "@hotwired/stimulus"

// Applies the theme immediately on toggle, then persists it. The optimistic
// update means the page never flashes the old theme while the request is in
// flight.
export default class extends Controller {
  static values = { current: String, url: String }

  toggle() {
    const next = this.resolved() === "dark" ? "light" : "dark"
    document.documentElement.dataset.theme = next
    this.currentValue = next
    this.persist(next)
  }

  resolved() {
    const explicit = document.documentElement.dataset.theme
    if (explicit === "dark" || explicit === "light") return explicit
    return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark"
  }

  async persist(theme) {
    if (!this.urlValue) return
    try {
      await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || ""
        },
        body: JSON.stringify({ user: { theme } })
      })
    } catch (error) {
      // A failed save only means the preference is not remembered next visit.
      console.warn("Could not save theme preference", error)
    }
  }
}
