import { Controller } from "@hotwired/stimulus"

// Progressive disclosure for lesson blocks: an explanation stays hidden until
// the learner has committed to a prediction (spec 4).
export default class extends Controller {
  static targets = ["panel", "trigger"]

  show() {
    this.panelTargets.forEach((panel) => { panel.hidden = false })
    this.triggerTargets.forEach((trigger) => { trigger.hidden = true })
  }

  toggle() {
    this.panelTargets.forEach((panel) => { panel.hidden = !panel.hidden })
  }
}
