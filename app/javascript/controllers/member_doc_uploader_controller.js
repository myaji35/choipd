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
  if (data?.error === "INVALID_EXT") return "이 파일은 올릴 수 없어요. 글 파일(.txt)로 올리거나 아래 칸에 바로 적어 주세요."
  if (data?.error === "FILE_TOO_LARGE") return "파일이 너무 커요. 1MB보다 작게 나눠 올려 주세요."
  if (data?.error === "DUPLICATE_CONTENT") return "같은 내용이 이미 올라가 있어요."
  if (data?.error === "EMPTY_FILE") return "내용이 비어 있어요."
  if (status === 0) return "인터넷 연결을 확인한 뒤 다시 해 주세요."
  return "올리지 못했어요. 잠시 뒤 다시 해 주세요."
}

export default class extends Controller {
  static targets = ["fileInput", "title", "category", "error", "status", "progress", "progressBar", "pasteText", "pasteButton", "pasteStatus"]
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

  async uploadText() {
    if (!this.hasPasteTextTarget || !this.hasPasteButtonTarget || !this.hasPasteStatusTarget) return

    const button = this.pasteButtonTarget
    if (button.disabled) return

    const content = this.pasteTextTarget.value.trim()
    const status = this.pasteStatusTarget
    status.style.color = "#b42318"
    if (content.length < 10) {
      status.textContent = "내용을 조금 더 적어 주세요. 한두 문장이면 돼요."
      return
    }
    if (new Blob([content]).size > 1024 * 1024) {
      status.textContent = "글이 너무 길어요. 둘로 나눠서 올려 주세요."
      return
    }

    button.disabled = true
    button.textContent = "올리는 중…"
    status.textContent = ""

    const now = new Date()
    const pad = value => String(value).padStart(2, "0")
    const date = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
    const time = `${pad(now.getHours())}${pad(now.getMinutes())}`
    const result = await this.uploadDocument({
      filename: `직접 쓴 글 ${date} ${time}.txt`,
      title: null,
      category: "career",
      content
    })

    if (result.ok) {
      status.style.color = "var(--impd-accent)"
      status.textContent = "올렸어요. 잠시 뒤 목록에 보여요."
      setTimeout(() => location.reload(), 600)
    } else {
      button.disabled = false
      button.textContent = "이 글 올리기"
      status.textContent = result.error
    }
  }

  async processFiles(files) {
    this.hideError()
    const total = files.length
    let ok = 0, fail = 0
    const failures = []

    this.showProgress()
    for (let i = 0; i < total; i++) {
      const file = files[i]
      this.statusTarget.textContent = `${file.name} 올리는 중… (${i + 1}/${total})`
      this.setProgress(Math.round((i / total) * 100))
      const result = await this.uploadOne(file)
      if (result.ok) ok++
      else { fail++; failures.push(`${file.name}: ${result.error}`) }
    }
    this.setProgress(100)

    if (fail === 0) {
      this.statusTarget.textContent = `${ok}개 올렸어요.`
      setTimeout(() => location.reload(), 600)
    } else {
      this.statusTarget.textContent = `${ok}개 올렸고 ${fail}개는 올리지 못했어요.`
      this.showError(failures.join(" · "))
      if (ok > 0) setTimeout(() => location.reload(), 1800)
    }
  }

  async uploadOne(file) {
    if (!/\.(md|markdown|txt)$/i.test(file.name)) {
      return { ok: false, error: "글 파일(.txt)만 올릴 수 있어요. 한글·워드·PDF는 내용을 복사해 아래 칸에 붙여 넣어 주세요." }
    }
    if (file.size > 1024 * 1024) {
      return { ok: false, error: "파일이 너무 커요. 1MB보다 작게 나눠 올려 주세요." }
    }
    try {
      const text = await file.text()
      if (!text.trim()) return { ok: false, error: "내용이 비어 있어요." }
      return await this.uploadDocument({
        filename: file.name,
        title: this.titleTarget.value || null,
        category: inferCategory(file.name),
        content: text
      })
    } catch {
      return { ok: false, error: errorMessage(null, 0) }
    }
  }

  async uploadDocument(document) {
    try {
      const res = await fetch(this.createUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this.csrfValue },
        body: JSON.stringify(document)
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success) return { ok: true }
      return { ok: false, error: errorMessage(data, res.status) }
    } catch {
      return { ok: false, error: errorMessage(null, 0) }
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
