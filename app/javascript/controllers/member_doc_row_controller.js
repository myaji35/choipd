import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { deleteUrl: String, reparseUrl: String, csrf: String, filename: String }

  async destroy(e) {
    e.preventDefault()
    if (!confirm(`'${this.filenameValue}' 을 삭제할까요?`)) return
    const res = await fetch(this.deleteUrlValue, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfValue, "Accept": "application/json" }
    })
    if (res.ok) {
      this.element.style.opacity = "0.3"
      setTimeout(() => location.reload(), 300)
    } else {
      alert("삭제 실패")
    }
  }

  async reparse(e) {
    e.preventDefault()
    const btn = e.currentTarget
    const prev = btn.textContent
    btn.textContent = "재추출 중…"
    btn.disabled = true
    const res = await fetch(this.reparseUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": this.csrfValue, "Accept": "application/json" }
    })
    if (res.ok) {
      btn.textContent = "✓ 완료"
      setTimeout(() => location.reload(), 500)
    } else {
      btn.textContent = prev
      btn.disabled = false
      alert("재추출 실패")
    }
  }
}
