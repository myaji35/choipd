import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  fill({ params: { field, value, next } }) {
    const input = this.element.querySelector(`#${CSS.escape(field)}`)
    if (!input) return

    if (input.value !== "") {
      input.focus()
      return
    }

    input.value = value
    input.dispatchEvent(new Event("input", { bubbles: true }))
    const nextInput = next && this.element.querySelector(`#${CSS.escape(next)}`)
    const focusTarget = nextInput || input
    focusTarget.focus()
  }
}
