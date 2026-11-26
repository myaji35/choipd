import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primary"]

  connect() {
    this.floatingAction = document.querySelector(".impd-frap-home")
    if (!this.floatingAction || !this.hasPrimaryTarget || !("IntersectionObserver" in window)) return

    const barHeight = document.querySelector(".impd-topnav-bar")?.offsetHeight || 0
    this.observer = new IntersectionObserver(([entry]) => {
      this.floatingAction.classList.toggle("is-hero-visible", entry.isIntersecting)
    }, { rootMargin: `-${barHeight}px 0px 0px 0px` })
    this.observer.observe(this.primaryTarget)
  }

  playPreview({ currentTarget: video }) {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return

    video.play().catch(() => {})
  }

  resetPreview({ currentTarget: video }) {
    video.pause()
    video.currentTime = 0
  }

  disconnect() {
    this.observer?.disconnect()
    this.floatingAction?.classList.remove("is-hero-visible")
  }
}
