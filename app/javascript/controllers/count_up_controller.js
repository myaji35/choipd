import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.value = +this.element.textContent
    this.media = matchMedia("(prefers-reduced-motion: reduce)")
    this.media.addEventListener("change", this.finish)
    if (this.media.matches) return
    const start = performance.now()
    const step = now => {
      const t = Math.min(1, (now - start) / 1000)
      this.element.textContent = Math.round(this.value * (1 - (1 - t) ** 3))
      if (t < 1) this.frame = requestAnimationFrame(step)
    }
    this.frame = requestAnimationFrame(step)
  }

  disconnect() {
    this.finish()
    this.media.removeEventListener("change", this.finish)
  }

  finish = () => {
    cancelAnimationFrame(this.frame)
    this.element.textContent = this.value
  }
}
