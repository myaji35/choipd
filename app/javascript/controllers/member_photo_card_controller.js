import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { deleteUrl: String, updateUrl: String, csrf: String, id: Number }

  connect() {
    const select = this.element.querySelector("select")
    if (select) select.dataset.previous = select.value
  }

  async updateCategory(e) {
    const select = e.currentTarget
    const previous = select.dataset.previous || select.defaultValue
    try {
      const res = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfValue, "Accept": "application/json" },
        body: JSON.stringify({ category: select.value })
      })
      if (!res.ok) throw new Error()
      select.dataset.previous = select.value
      this.element.querySelector("[data-category-chip]").textContent = select.selectedOptions[0].textContent
    } catch (_) {
      select.value = previous
      alert("분류를 저장하지 못했습니다.")
    }
  }

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
