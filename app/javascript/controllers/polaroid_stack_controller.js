import { Controller } from "@hotwired/stimulus"

// Stacked Polaroids — 2.4초마다 맨 위 카드가 사라지며 맨 뒤로 순환
export default class extends Controller {
  static targets = ["card"]

  connect() {
    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      // 모션 줄임 사용자: 정적 스택만 표시
      this.applyDepth(0)
      return
    }
    this.tick = 0
    this.applyDepth(this.tick)
    this.intervalId = setInterval(() => {
      this.tick = this.tick + 1
      this.applyDepth(this.tick)
    }, 2400)
  }

  disconnect() {
    if (this.intervalId) clearInterval(this.intervalId)
  }

  applyDepth(tick) {
    const cards = this.cardTargets
    const N = cards.length
    if (N === 0) return
    const rots = [-6, 4, -3, 7, -4, 5]
    const dx = [0, 10, -8, 14, -6, 8]
    const dy = [0, 8, 16, 24, 32, 40]

    cards.forEach((card, i) => {
      const depth = (i - tick + N * 10) % N
      const isTop = depth === 0
      const leaving = depth === N - 1
      const scale = 1 - depth * 0.02
      const tx = dx[depth % dx.length]
      const ty = dy[depth % dy.length]
      const rot = rots[depth % rots.length]

      card.style.transform = `translate(${tx}px, ${ty}px) rotate(${rot}deg) scale(${scale})`
      card.style.zIndex = N - depth
      card.style.opacity = leaving ? "0" : "1"
      card.style.boxShadow = isTop
        ? "0 28px 50px rgba(0,0,0,0.22), 0 4px 10px rgba(0,0,0,0.12)"
        : "0 10px 24px rgba(0,0,0,0.14)"
    })
  }
}
