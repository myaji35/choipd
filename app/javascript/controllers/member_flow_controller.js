import { Controller } from "@hotwired/stimulus"

const key = "impd-flow-paused"

export default class extends Controller {
  static targets = ["window", "track", "pause"]

  connect() {
    this.flags = this.element.classList
    this.second = [...(this.trackTargets[1]?.children || [])]
    this.media = matchMedia("(prefers-reduced-motion: reduce)")
    this.media.addEventListener("change", this.layout)
    this.observer = new IntersectionObserver(entries => {
      for (const { target, isIntersecting } of entries) {
        if (target === this.element) this.flags.toggle("is-outside", !isIntersecting)
        else if (isIntersecting) {
          target.src = target.dataset.src
          this.observer.unobserve(target)
        }
      }
    })
    this.visibility()
    this.pause(sessionStorage.getItem(key) === "true")
    this.layout()
  }

  disconnect() {
    this.media.removeEventListener("change", this.layout)
    this.reset()
  }

  reset() {
    this.observer.disconnect()
    this.flags.remove("is-live", "is-ready")
    this.element.querySelectorAll("[data-copy]").forEach(copy => copy.remove())
    this.trackTargets[1]?.append(...this.second)
    this.pauseTarget.hidden = true
  }

  layout = () => {
    this.width = innerWidth
    this.reset()
    if (!this.media.matches) this.start()
    this.observer.observe(this.element)
    this.element.closest(".impd-home").querySelectorAll("img[data-src]:not([src])").forEach(img => this.observer.observe(img))
  }

  start() {
    if (this.hasWindowTarget) {
      const horizontal = innerWidth <= 768
      const tracks = this.trackTargets.slice(0, innerWidth < 1200 ? 1 : 2)
      if (tracks.length === 1) tracks[0].append(...this.second)
      this.flags.add("is-ready")
      const size = horizontal ? "offsetWidth" : "offsetHeight"
      const lengths = tracks.map(track => track[size] + parseFloat(getComputedStyle(track).gap))
      if (lengths.some(length => length < this.windowTarget[size] * 1.25)) return this.reset()
      tracks.forEach((track, index) => {
        const length = lengths[index]
        track.style.cssText = `--flow-shift: -${length}px; --flow-dur: ${length / (horizontal ? 24 : 18)}s`
        const copies = Array.from(track.children, card => {
          const copy = card.cloneNode(true)
          copy.dataset.copy = ""
          copy.ariaHidden = "true"
          copy.inert = true
          copy.tabIndex = -1
          return copy
        })
        index ? track.prepend(...copies) : track.append(...copies)
      })
    }
    this.pauseTarget.hidden = false
    this.flags.add("is-live")
  }

  resize() {
    if (innerWidth !== this.width) this.layout()
  }

  visibility() {
    this.flags.toggle("is-hidden", document.hidden)
  }

  toggle() {
    const paused = !this.flags.contains("is-paused")
    sessionStorage.setItem(key, paused)
    this.pause(paused)
  }

  pause(paused) {
    this.flags.toggle("is-paused", paused)
    const button = this.pauseTarget
    button.ariaPressed = paused
    button.ariaLabel = paused ? "회원 흐름 다시 재생" : "회원 흐름 멈추기"
    button.lastElementChild.textContent = paused ? "다시 재생" : "멈춤"
  }
}
