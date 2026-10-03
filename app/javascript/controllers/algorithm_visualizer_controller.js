import { Controller } from "@hotwired/stimulus"

// Steps through a server-computed trace of a real algorithm (spec 7).
//
// The frames come from the Ruby tracer, so what the learner watches is the
// actual execution, not a hand-drawn animation. This controller only renders
// whichever frame is current and never computes the algorithm itself.
export default class extends Controller {
  static targets = [
    "stage", "narration", "counter", "playButton", "aux", "auxLabel",
    "auxItems", "metrics", "scrubber"
  ]
  static values = {
    frames: Array,
    kind: { type: String, default: "array" },
    speed: { type: Number, default: 700 },
    reducedMotion: { type: Boolean, default: false }
  }

  connect() {
    this.index = 0
    this.playing = false
    this.render()
  }

  disconnect() {
    this.pause()
  }

  // ---------------------------------------------------------- transport
  next() {
    if (this.index < this.framesValue.length - 1) {
      this.index++
      this.render()
    } else {
      this.pause()
    }
  }

  previous() {
    if (this.index > 0) {
      this.index--
      this.render()
    }
  }

  first() {
    this.index = 0
    this.render()
  }

  last() {
    this.index = this.framesValue.length - 1
    this.render()
  }

  scrub(event) {
    this.index = Math.min(
      Math.max(parseInt(event.target.value, 10) || 0, 0),
      this.framesValue.length - 1
    )
    this.render()
  }

  toggle() {
    this.playing ? this.pause() : this.play()
  }

  play() {
    if (this.index >= this.framesValue.length - 1) this.index = 0
    this.playing = true
    this.updatePlayButton()
    // Honouring reduced motion means stepping without the animated delay.
    const interval = this.reducedMotionValue ? 120 : this.speedValue
    this.timer = setInterval(() => this.next(), interval)
  }

  pause() {
    this.playing = false
    clearInterval(this.timer)
    this.updatePlayButton()
  }

  setSpeed(event) {
    this.speedValue = parseInt(event.target.value, 10)
    if (this.playing) {
      this.pause()
      this.play()
    }
  }

  // Keyboard stepping, so the visualiser is usable without a mouse.
  keydown(event) {
    const keys = { ArrowRight: () => this.next(), ArrowLeft: () => this.previous(),
                   Home: () => this.first(), End: () => this.last(),
                   " ": () => this.toggle() }
    const action = keys[event.key]
    if (action) {
      event.preventDefault()
      action()
    }
  }

  // ------------------------------------------------------------ rendering
  get frame() {
    return this.framesValue[this.index] || {}
  }

  render() {
    const frame = this.frame
    if (this.hasNarrationTarget) {
      this.narrationTarget.textContent = frame.narration || ""
    }
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `Step ${this.index + 1} / ${this.framesValue.length}`
    }
    if (this.hasScrubberTarget) {
      this.scrubberTarget.max = Math.max(this.framesValue.length - 1, 0)
      this.scrubberTarget.value = this.index
    }
    this.renderMetrics(frame)
    this.renderAux(frame)

    switch (this.kindValue) {
      case "graph": this.renderGraph(frame); break
      case "dp_table": this.renderTable(frame); break
      default: this.renderArray(frame)
    }
    if (this.index >= this.framesValue.length - 1) this.pause()
  }

  renderMetrics(frame) {
    if (!this.hasMetricsTarget) return
    const m = frame.metrics || {}
    const parts = []
    if (m.comparisons !== undefined) parts.push(`${m.comparisons} comparisons`)
    if (m.swaps !== undefined) parts.push(`${m.swaps} swaps`)
    this.metricsTarget.textContent = parts.join(" · ")
  }

  renderAux(frame) {
    if (!this.hasAuxTarget) return
    const aux = frame.aux
    if (!aux || !aux.items) {
      this.auxTarget.hidden = true
      return
    }
    this.auxTarget.hidden = false
    if (this.hasAuxLabelTarget) this.auxLabelTarget.textContent = aux.label || ""
    if (this.hasAuxItemsTarget) {
      this.auxItemsTarget.replaceChildren(
        ...(aux.items.length === 0
          ? [this.chip("empty", true)]
          : aux.items.map((item) => this.chip(item)))
      )
    }
  }

  chip(text, muted = false) {
    const el = document.createElement("span")
    el.className = muted ? "chip text-faint" : "chip"
    el.textContent = String(text)
    return el
  }

  renderArray(frame) {
    const values = Array.isArray(frame.data) ? frame.data : []
    if (values.length === 0) {
      this.stageTarget.replaceChildren()
      return
    }
    const markers = frame.markers || {}
    const max = Math.max(...values.map((v) => Math.abs(Number(v) || 0)), 1)

    const bars = values.map((value, index) => {
      const bar = document.createElement("div")
      bar.className = `bar ${this.barModifier(index, markers)}`
      const height = Math.max((Math.abs(Number(value) || 0) / max) * 150, 10)
      bar.style.height = `${height}px`
      bar.setAttribute("role", "listitem")
      bar.setAttribute("aria-label", `index ${index}, value ${value}`)

      const idx = document.createElement("span")
      idx.className = "bar__index"
      idx.textContent = index
      const val = document.createElement("span")
      val.className = "bar__value"
      val.textContent = value
      bar.append(idx, val)
      return bar
    })
    this.stageTarget.setAttribute("role", "list")
    this.stageTarget.replaceChildren(...bars)
  }

  // Marker precedence: the most specific state wins so a swapping bar is not
  // also painted as merely "compared".
  barModifier(index, markers) {
    const inPair = (key) => Array.isArray(markers[key]) && markers[key].includes(index)
    const inWindow = Array.isArray(markers.window) &&
      index >= markers.window[0] && index <= markers.window[1]

    if (markers.found === index || markers.also_found === index) return "bar--found"
    if (inPair("swap")) return "bar--swap"
    if (markers.pivot === index) return "bar--pivot"
    if (inPair("compare")) return "bar--compare"
    if (markers.current === index) return "bar--current"
    if (markers.entering === index) return "bar--current"
    if (inPair("sorted")) return "bar--sorted"
    if (inWindow) return "bar--window"
    if (markers.window && !inWindow) return "bar--dim"
    return ""
  }

  renderGraph(frame) {
    const data = frame.data || {}
    const markers = frame.markers || {}
    const nodes = data.nodes || []
    const visited = markers.visited || []
    const frontier = markers.frontier || []

    const wrap = document.createElement("div")
    wrap.className = "graph"
    const row = document.createElement("div")
    row.className = "graph__row"

    nodes.forEach((name) => {
      const el = document.createElement("div")
      let cls = "graph-node"
      if (markers.current === name) cls += " graph-node--current"
      else if (visited.includes(name)) cls += " graph-node--visited"
      else if (frontier.includes(name)) cls += " graph-node--frontier"
      el.className = cls
      el.textContent = name
      el.setAttribute("aria-label", this.graphNodeLabel(name, markers, visited, frontier))
      row.append(el)
    })

    const edges = document.createElement("div")
    edges.className = "graph__edges"
    edges.textContent = (data.edges || []).map(([a, b]) => `${a}→${b}`).join("   ")

    wrap.append(row, edges)
    this.stageTarget.style.alignItems = "center"
    this.stageTarget.replaceChildren(wrap)
  }

  graphNodeLabel(name, markers, visited, frontier) {
    if (markers.current === name) return `${name}, current`
    if (visited.includes(name)) return `${name}, visited`
    if (frontier.includes(name)) return `${name}, in frontier`
    return `${name}, unvisited`
  }

  renderTable(frame) {
    const cells = (frame.data || {}).cells || []
    const markers = frame.markers || {}
    const wrap = document.createElement("div")
    wrap.className = "dp-table"

    cells.forEach((cell) => {
      const el = document.createElement("div")
      let cls = "dp-cell"
      if (markers.current === cell.index) cls += " dp-cell--current"
      else if (Array.isArray(markers.depends_on) && markers.depends_on.includes(cell.index)) {
        cls += " dp-cell--depends"
      } else if (Array.isArray(markers.solved) && markers.solved.includes(cell.index)) {
        cls += " dp-cell--solved"
      }
      if (cell.value === null || cell.value === undefined) cls += " dp-cell--empty"
      el.className = cls

      const label = document.createElement("span")
      label.className = "dp-cell__label"
      label.textContent = cell.label
      const value = document.createElement("span")
      value.className = "dp-cell__value"
      value.textContent = cell.value === null || cell.value === undefined ? "—" : cell.value
      el.append(label, value)
      wrap.append(el)
    })

    this.stageTarget.style.alignItems = "center"
    this.stageTarget.replaceChildren(wrap)
  }

  updatePlayButton() {
    if (!this.hasPlayButtonTarget) return
    this.playButtonTarget.textContent = this.playing ? "Pause" : "Play"
    this.playButtonTarget.setAttribute("aria-pressed", String(this.playing))
  }
}
