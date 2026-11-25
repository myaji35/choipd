import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "status"]

  async copy() {
    const request = Symbol()
    this.copyRequest = request
    clearTimeout(this.resetTimer)

    try {
      if (!navigator.clipboard?.writeText) {
        this.selectForManualCopy()
        return
      }
      await navigator.clipboard.writeText(this.sourceTarget.value)
    } catch {
      if (this.copyRequest === request) this.selectForManualCopy()
      return
    }

    if (this.copyRequest !== request) return

    this.buttonTarget.textContent = "복사했어요"
    this.statusTarget.textContent = ""
    this.resetTimer = setTimeout(() => {
      this.buttonTarget.textContent = "안내 복사"
    }, 2000)
  }

  selectForManualCopy() {
    const source = this.sourceTarget
    source.focus()
    source.select()
    source.setSelectionRange(0, source.value.length)
    this.buttonTarget.textContent = "안내 복사"
    this.statusTarget.textContent = "복사가 안 되면 글을 길게 눌러 복사해 주세요"
  }

  disconnect() {
    clearTimeout(this.resetTimer)
    this.copyRequest = null
  }
}
