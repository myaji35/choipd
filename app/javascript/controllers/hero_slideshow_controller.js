import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "indicators"]
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.currentIndex = 0
    if (this.slideTargets.length > 1) {
      this.startAutoplay()
    }
  }

  disconnect() {
    this.stopAutoplay()
  }

  startAutoplay() {
    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  stopAutoplay() {
    if (this.timer) clearInterval(this.timer)
  }

  next() {
    this.goTo({ params: { index: (this.currentIndex + 1) % this.slideTargets.length } })
  }

  goTo({ params }) {
    const index = parseInt(params.index ?? params)
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("opacity-100", i === index)
      slide.classList.toggle("opacity-0", i !== index)
    })

    // 인디케이터 업데이트
    if (this.hasIndicatorsTarget) {
      const buttons = this.indicatorsTarget.querySelectorAll("button")
      buttons.forEach((btn, i) => {
        btn.classList.toggle("bg-white", i === index)
        btn.classList.toggle("w-6", i === index)
        btn.classList.toggle("bg-white/40", i !== index)
        btn.classList.toggle("w-2", i !== index)
      })
    }

    this.currentIndex = index
  }
}
