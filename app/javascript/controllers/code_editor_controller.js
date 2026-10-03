import { Controller } from "@hotwired/stimulus"

// A plain <textarea> editor with a line-number gutter.
//
// Deliberately not a third-party editor widget: a real textarea keeps full
// keyboard support, screen-reader behaviour and browser autofill intact
// (spec 72), and adds no runtime dependency.
export default class extends Controller {
  static targets = ["area", "gutter", "status"]
  static values = { indent: { type: Number, default: 2 } }

  connect() {
    this.renderGutter()
    this.syncScroll()
  }

  input() {
    this.renderGutter()
  }

  renderGutter() {
    if (!this.hasGutterTarget) return
    const lines = this.areaTarget.value.split("\n").length
    const numbers = []
    for (let i = 1; i <= lines; i++) numbers.push(i)
    this.gutterTarget.textContent = numbers.join("\n")
  }

  syncScroll() {
    if (!this.hasGutterTarget) return
    this.gutterTarget.scrollTop = this.areaTarget.scrollTop
  }

  // Tab inserts spaces instead of moving focus, which is what a code editor
  // must do. Escape then Tab still leaves the field for keyboard users.
  keydown(event) {
    if (event.key === "Tab" && !this.escapedOnce) {
      event.preventDefault()
      this.insert(" ".repeat(this.indentValue))
      return
    }
    if (event.key === "Escape") {
      this.escapedOnce = true
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Tab will now move focus out of the editor."
      }
      return
    }
    this.escapedOnce = false

    // Enter keeps the current indentation, so blocks do not collapse left.
    if (event.key === "Enter") {
      const area = this.areaTarget
      const start = area.selectionStart
      const lineStart = area.value.lastIndexOf("\n", start - 1) + 1
      const current = area.value.slice(lineStart, start)
      const indent = (current.match(/^[ \t]*/) || [""])[0]
      const extra = /(\bdo\b|\{|\bif\b|\bdef\b|\bclass\b|\bmodule\b|\belse\b)\s*$/.test(current)
        ? " ".repeat(this.indentValue)
        : ""
      if (indent.length > 0 || extra.length > 0) {
        event.preventDefault()
        this.insert("\n" + indent + extra)
      }
    }
  }

  insert(text) {
    const area = this.areaTarget
    const start = area.selectionStart
    const end = area.selectionEnd
    area.setRangeText(text, start, end, "end")
    this.renderGutter()
    area.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // Ctrl/Cmd+Enter submits, the convention in every code playground.
  submitShortcut(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      this.element.closest("form")?.requestSubmit()
    }
  }
}
