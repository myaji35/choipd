import { Controller } from "@hotwired/stimulus"

function errorMessage(data, status) {
  if (data?.message) return data.message
  if (data?.error === "NO_FILE") return "파일 선택 안 됨"
  if (status === 413) return "파일이 너무 큽니다 (15MB 초과)"
  if (status === 0) return "네트워크 오류"
  return `실패 (HTTP ${status})`
}

export default class extends Controller {
  static targets = ["cameraInput", "galleryInput", "category", "error", "status", "progress", "progressBar"]
  static values = { createUrl: String, csrf: String }

  dragover(e) {
    e.preventDefault()
    e.currentTarget.style.background = "rgba(255,90,31,.08)"
  }
  dragleave(e) {
    e.currentTarget.style.background = ""
  }
  drop(e) {
    e.preventDefault()
    e.currentTarget.style.background = ""
    const files = Array.from(e.dataTransfer.files).filter(f => f.type.startsWith("image/"))
    if (files.length) this.processFiles(files)
  }

  fileSelected(e) {
    const files = Array.from(e.target.files)
    if (files.length) this.processFiles(files)
    e.target.value = ""
  }

  async processFiles(files) {
    this.hideError()
    const total = files.length
    let ok = 0
    const failures = []
    const category = this.hasCategoryTarget ? this.categoryTarget.value : "daily"

    this.showProgress()
    for (let i = 0; i < total; i++) {
      const file = files[i]
      this.statusTarget.textContent = `[${i + 1}/${total}] ${file.name} — 업로드 중…`
      this.setProgress(Math.round((i / total) * 100))
      const result = await this.uploadOne(file, category)
      if (result.ok) ok++
      else failures.push(`${file.name}: ${result.error}`)
    }
    this.setProgress(100)

    if (failures.length === 0) {
      this.statusTarget.textContent = `✓ ${ok}장 업로드 완료`
      setTimeout(() => window.location.reload(), 500)
    } else {
      this.showError(failures.join("\n"))
      if (ok > 0) {
        this.statusTarget.textContent = `부분 성공: ${ok}/${total}. 페이지를 새로고침하여 확인하세요.`
      }
    }
    setTimeout(() => this.hideProgress(), 1500)
  }

  async uploadOne(file, category) {
    const fd = new FormData()
    fd.append("files[]", file)
    fd.append("category", category)
    try {
      const res = await fetch(this.createUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": this.csrfValue, "Accept": "application/json" },
        body: fd,
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success) return { ok: true }
      return { ok: false, error: errorMessage(data, res.status) }
    } catch (err) {
      return { ok: false, error: err.message || "네트워크 오류" }
    }
  }

  showProgress() { this.progressTarget.style.display = "block" }
  hideProgress() { this.progressTarget.style.display = "none" }
  setProgress(pct) { this.progressBarTarget.style.width = `${pct}%` }
  showError(msg) {
    this.errorTarget.textContent = msg
    this.errorTarget.style.display = "block"
  }
  hideError() {
    this.errorTarget.style.display = "none"
    this.errorTarget.textContent = ""
  }
}
