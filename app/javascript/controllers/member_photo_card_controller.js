import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { deleteUrl: String, csrf: String, id: Number }

  async destroy(e) {
    e.preventDefault()
    if (!confirm("이 사진을 삭제하시겠습니까?")) return
    try {
      const res = await fetch(this.deleteUrlValue, {
        method: "DELETE",
        headers: { "X-CSRF-Token": this.csrfValue, "Accept": "application/json" },
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success) {
        this.element.style.opacity = "0"
        setTimeout(() => this.element.remove(), 200)
      } else {
        alert(data.message || "삭제 실패")
      }
    } catch (err) {
      alert("네트워크 오류: " + err.message)
    }
  }
}
