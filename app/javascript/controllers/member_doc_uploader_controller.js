import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "title", "category", "error", "status"]
  static values = { createUrl: String, csrf: String }

  dragover(e) { e.preventDefault(); e.currentTarget.classList.add("border-primary", "bg-blue-50") }
  dragleave(e) { e.currentTarget.classList.remove("border-primary", "bg-blue-50") }
  drop(e) {
    e.preventDefault()
    e.currentTarget.classList.remove("border-primary", "bg-blue-50")
    const file = e.dataTransfer.files[0]
    if (file) this.processFile(file)
  }
  fileSelected(e) {
    const file = e.target.files[0]
    if (file) this.processFile(file)
  }

  async processFile(file) {
    if (!/\.(md|markdown|txt)$/i.test(file.name)) {
      return this.showError(".md / .markdown / .txt 파일만 허용됩니다.")
    }
    if (file.size > 1024 * 1024) {
      return this.showError("최대 1MB")
    }
    this.statusTarget.textContent = "업로드 중..."
    const text = await file.text()
    try {
      const res = await fetch(this.createUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this.csrfValue },
        body: JSON.stringify({
          filename: file.name,
          title: this.titleTarget.value || null,
          category: this.categoryTarget.value,
          content: text
        })
      })
      const data = await res.json()
      if (data.success) {
        this.statusTarget.textContent = "✓ 업로드 완료"
        setTimeout(() => location.reload(), 500)
      } else {
        this.showError(data.error || (data.errors || []).join(", ") || "업로드 실패")
      }
    } catch (e) {
      this.showError(e.message)
    }
  }

  showError(msg) {
    this.errorTarget.textContent = msg
    this.errorTarget.classList.remove("hidden")
    this.statusTarget.textContent = ""
  }
}
