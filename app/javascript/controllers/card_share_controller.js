import { Controller } from "@hotwired/stimulus"

// 디지털 명함 공유 버튼.
// 짧은 주소 복사 / 네이티브 공유 시트(모바일) / 폴백(클립보드).
export default class extends Controller {
  static targets = ["flash"]
  static values = { shortUrl: String, profileUrl: String }

  async copyShort(e) {
    e.preventDefault()
    await this.copy(this.shortUrlValue)
    this.flash("✓ 짧은 주소가 복사되었습니다")
  }

  async shareNative(e) {
    e.preventDefault()
    const shareData = {
      title: document.title || "imPD 디지털 명함",
      text: "흩어진 내 일, 하나의 주소로 — imPD",
      url: this.shortUrlValue || this.profileUrlValue,
    }
    if (navigator.share && navigator.canShare?.(shareData)) {
      try { await navigator.share(shareData); return } catch (_) { /* cancelled */ }
    }
    // 폴백: 클립보드 복사 + 안내
    await this.copy(this.shortUrlValue)
    this.flash("✓ 링크 복사됨 — 카톡에 붙여넣으세요")
  }

  async copy(text) {
    try {
      await navigator.clipboard.writeText(text)
    } catch (_) {
      const ta = document.createElement("textarea")
      ta.value = text
      document.body.appendChild(ta)
      ta.select()
      try { document.execCommand("copy") } catch (_) {}
      document.body.removeChild(ta)
    }
  }

  flash(msg) {
    if (!this.hasFlashTarget) return
    this.flashTarget.textContent = msg
    this.flashTarget.style.opacity = "1"
    clearTimeout(this._flashTimer)
    this._flashTimer = setTimeout(() => { this.flashTarget.style.opacity = "0" }, 2200)
  }
}
