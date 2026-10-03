import { Controller } from "@hotwired/stimulus"

// The Big-O visualiser (spec 9). Moving the slider recomputes real operation
// counts for each growth class, so the learner sees why O(n^2) stops being
// viable rather than being told so.
export default class extends Controller {
  static targets = ["row", "size", "verdict"]
  static values = { opsPerSecond: { type: Number, default: 100000000 } }

  connect() {
    this.update()
  }

  update() {
    const n = this.currentSize()
    if (this.hasSizeTarget) {
      this.sizeTarget.textContent = n.toLocaleString()
    }

    const counts = this.rowTargets.map((row) => this.operations(row.dataset.curve, n))
    // Scale bars against the largest finite count so the comparison is honest.
    const finite = counts.filter((c) => Number.isFinite(c))
    const max = finite.length ? Math.max(...finite) : 1

    this.rowTargets.forEach((row, i) => {
      const ops = counts[i]
      const fill = row.querySelector("[data-fill]")
      const value = row.querySelector("[data-value]")

      // Log scale: on a linear scale every curve but the worst is invisible.
      const ratio = Number.isFinite(ops)
        ? Math.log10(Math.max(ops, 1)) / Math.log10(Math.max(max, 10))
        : 1
      if (fill) {
        fill.style.width = `${Math.max(ratio * 100, 1)}%`
        fill.className = `bigo__fill ${this.severity(ops)}`
      }
      if (value) value.textContent = this.describe(ops)
    })

    if (this.hasVerdictTarget) this.verdictTarget.textContent = this.verdict(n)
  }

  currentSize() {
    const raw = this.element.querySelector("[data-complexity-slider]")
    const steps = [10, 100, 1000, 10000, 100000, 1000000]
    const index = raw ? parseInt(raw.value, 10) : 2
    return steps[Math.min(Math.max(index, 0), steps.length - 1)]
  }

  operations(curve, n) {
    switch (curve) {
      case "constant": return 1
      case "log": return Math.ceil(Math.log2(n))
      case "linear": return n
      case "linearithmic": return Math.round(n * Math.log2(n))
      case "quadratic": return n * n
      case "exponential": return n <= 40 ? Math.pow(2, n) : Infinity
      default: return n
    }
  }

  severity(ops) {
    if (!Number.isFinite(ops)) return "bigo__fill--danger"
    const seconds = ops / this.opsPerSecondValue
    if (seconds > 60) return "bigo__fill--danger"
    if (seconds > 1) return "bigo__fill--warning"
    return "bigo__fill--success"
  }

  describe(ops) {
    if (!Number.isFinite(ops)) return "beyond counting"
    const seconds = ops / this.opsPerSecondValue
    const count = ops >= 1e9
      ? `${(ops / 1e9).toPrecision(3)}e9 ops`
      : `${Math.round(ops).toLocaleString()} ops`
    return `${count} · ${this.duration(seconds)}`
  }

  duration(seconds) {
    if (seconds < 0.001) return "instant"
    if (seconds < 1) return `${(seconds * 1000).toFixed(0)}ms`
    if (seconds < 60) return `${seconds.toFixed(1)}s`
    if (seconds < 3600) return `${(seconds / 60).toFixed(1)} min`
    if (seconds < 86400 * 365) return `${(seconds / 3600).toFixed(1)} hours`
    return "longer than a year"
  }

  verdict(n) {
    if (n <= 100) return "At this size almost anything works. Choose for clarity."
    if (n <= 10000) return "O(n^2) is still tolerable here, but it is the first thing to fix."
    if (n <= 100000) return "O(n^2) is now seconds of work. You want O(n log n) or better."
    return "At a million records only O(1), O(log n), O(n) and O(n log n) are acceptable."
  }
}
