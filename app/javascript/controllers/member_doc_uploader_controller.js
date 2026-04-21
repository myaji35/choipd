import { Controller } from "@hotwired/stimulus"

const CATEGORY_RULES = [
  [/(이력|career|cv|resume|profile|bio)/i, "career"],
  [/(수료|certificate|cert|license|자격|awards?)/i, "certificate"],
  [/(후기|review|testimonial|추천|interview)/i, "review"],
  [/(강의|course|lecture|커리큘럼|syllabus|curriculum)/i, "course"],
  [/(언론|press|기사|보도|media)/i, "press"],
  [/(작품|portfolio|work|gallery)/i, "portfolio"]
]

function inferCategory(filename) {
  for (const [re, cat] of CATEGORY_RULES) if (re.test(filename)) return cat
  return "other"
}

function errorMessage(data, status) {
  if (data?.message) return data.message
  if (data?.error === "INVALID_EXT") return "지원되지 않는 확장자"
  if (data?.error === "FILE_TOO_LARGE") return "1MB 초과"
  if (data?.error === "DUPLICATE_CONTENT") return "동일 내용 중복"
  if (data?.error === "EMPTY_FILE") return "빈 파일"
  if (status === 0) return "네트워크 오류"
  return `실패 (HTTP ${status})`
}

export default class extends Controller {
  static targets = ["fileInput", "title", "category", "error", "status", "progress", "progressBar"]
  static values = { createUrl: String, csrf: String }

  dragover(e) { e.preventDefault(); e.currentTarget.classList.add("border-primary", "bg-blue-50") }
  dragleave(e) { e.currentTarget.classList.remove("border-primary", "bg-blue-50") }
  drop(e) {
    e.preventDefault()
    e.currentTarget.classList.remove("border-primary", "bg-blue-50")
    const files = Array.from(e.dataTransfer.files)
    if (files.length) this.processFiles(files)
  }
  fileSelected(e) {
    const files = Array.from(e.target.files)
    if (files.length) this.processFiles(files)
  }

  async processFiles(files) {
    this.hideError()
    const total = files.length
    let ok = 0, fail = 0
    const failures = []

    this.showProgress()
    for (let i = 0; i < total; i++) {
      const file = files[i]
      this.statusTarget.textContent = `[${i + 1}/${total}] ${file.name} — 업로드 중…`
      this.setProgress(Math.round((i / total) * 100))
      const result = await this.uploadOne(file)
      if (result.ok) ok++
      else { fail++; failures.push(`${file.name}: ${result.error}`) }
    }
    this.setProgress(100)

    if (fail === 0) {
      this.statusTarget.textContent = `✓ ${ok}개 업로드 완료`
      setTimeout(() => location.reload(), 600)
    } else {
      this.statusTarget.textContent = `${ok}개 성공 · ${fail}개 실패`
      this.showError(failures.join(" · "))
      if (ok > 0) setTimeout(() => location.reload(), 1800)
    }
  }

  async uploadOne(file) {
    if (!/\.(md|markdown|txt)$/i.test(file.name)) {
      return { ok: false, error: "확장자 불가 (.md/.txt만)" }
    }
    if (file.size > 1024 * 1024) {
      return { ok: false, error: "1MB 초과" }
    }
    try {
      const text = await file.text()
      if (!text.trim()) return { ok: false, error: "빈 파일" }
      const res = await fetch(this.createUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this.csrfValue },
        body: JSON.stringify({
          filename: file.name,
          title: this.titleTarget.value || null,
          category: inferCategory(file.name),
          content: text
        })
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success) return { ok: true }
      return { ok: false, error: errorMessage(data, res.status) }
    } catch (e) {
      return { ok: false, error: e.message || "네트워크 오류" }
    }
  }

  showProgress() {
    if (this.hasProgressTarget) this.progressTarget.style.display = "block"
  }
  setProgress(pct) {
    if (this.hasProgressBarTarget) this.progressBarTarget.style.width = `${pct}%`
  }

  showError(msg) {
    this.errorTarget.textContent = msg
    this.errorTarget.style.display = "block"
  }
  hideError() {
    this.errorTarget.style.display = "none"
    this.errorTarget.textContent = ""
  }
}
