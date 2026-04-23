import { Controller } from "@hotwired/stimulus"

const IMAGE_MAX_BYTES = 25 * 1024 * 1024   // 서버 이미지 한도
const COMPRESS_TARGET_BYTES = 20 * 1024 * 1024  // 압축 목표(한도 여유 5MB)
const COMPRESS_MAX_SIDE = 3840             // 최대 긴 변 픽셀 (4K)

function errorMessage(data, status) {
  if (data?.message) return data.message
  if (data?.error === "NO_FILE") return "파일 선택 안 됨"
  if (status === 413) return "파일이 너무 큽니다 (이미지 25MB / 영상 100MB 초과)"
  if (status === 0) return "네트워크 오류"
  return `실패 (HTTP ${status})`
}

// 브라우저에서 이미지 자동 압축.
// 큰 카톡 사진(30~60MB JPEG/HEIC)을 Canvas로 리사이즈 + 품질 조정해 20MB 이하로 변환.
// HEIC 는 Safari 외 브라우저가 디코딩 못 할 수 있음 → 원본 반환하고 안내.
async function compressIfNeeded(file, onProgress) {
  if (!file.type.startsWith("image/")) return { file, compressed: false }
  if (file.size <= IMAGE_MAX_BYTES) return { file, compressed: false }

  const isHeic = /heic|heif/i.test(file.type) || /\.(heic|heif)$/i.test(file.name)

  onProgress?.(`${file.name} — ${(file.size / 1024 / 1024).toFixed(1)}MB 압축 중…`)
  try {
    const img = await loadImage(file)
    const ratio = Math.min(COMPRESS_MAX_SIDE / Math.max(img.width, img.height), 1)
    const canvas = document.createElement("canvas")
    canvas.width  = Math.round(img.width  * ratio)
    canvas.height = Math.round(img.height * ratio)
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height)

    const qualities = [0.92, 0.88, 0.82, 0.72, 0.6]
    let blob = null
    for (const q of qualities) {
      blob = await canvasToBlob(canvas, "image/jpeg", q)
      if (blob.size <= COMPRESS_TARGET_BYTES) break
    }
    const baseName = file.name.replace(/\.(heic|heif|png|webp|avif|bmp|jpe?g)$/i, "")
    const compressed = new File([blob], `${baseName}.jpg`, { type: "image/jpeg", lastModified: Date.now() })
    onProgress?.(`${file.name} — 압축 완료 ${(file.size / 1024 / 1024).toFixed(1)} → ${(compressed.size / 1024 / 1024).toFixed(1)}MB`)
    return { file: compressed, compressed: true }
  } catch (err) {
    const hint = isHeic ? " (HEIC 는 일부 브라우저 미지원 — 아이폰 설정 > 카메라 > 포맷 > '호환성 우선' 체크 후 재촬영)" : ""
    return { file, compressed: false, note: `압축 실패${hint}` }
  }
}

function loadImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload  = () => { URL.revokeObjectURL(url); resolve(img) }
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("이미지 디코딩 실패")) }
    img.src = url
  })
}
function canvasToBlob(canvas, type, quality) {
  return new Promise(resolve => canvas.toBlob(resolve, type, quality))
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
    const notes = []
    for (let i = 0; i < total; i++) {
      const original = files[i]
      this.statusTarget.textContent = `[${i + 1}/${total}] ${original.name} — 준비…`
      this.setProgress(Math.round((i / total) * 100))

      // 25MB 초과 이미지는 자동 리사이즈 + 품질 조정
      const { file, compressed, note } = await compressIfNeeded(original, msg => {
        this.statusTarget.textContent = `[${i + 1}/${total}] ${msg}`
      })
      if (note) notes.push(`${original.name}: ${note}`)

      this.statusTarget.textContent = `[${i + 1}/${total}] ${file.name} — 업로드 중${compressed ? " (압축됨)" : ""}…`
      const result = await this.uploadOne(file, category)
      if (result.ok) ok++
      else failures.push(`${file.name}: ${result.error}`)
    }
    this.setProgress(100)

    if (failures.length === 0) {
      this.statusTarget.textContent = `✓ ${ok}장 업로드 완료${notes.length ? ` (${notes.length}건 안내)` : ""}`
      if (notes.length) this.showError(notes.join("\n"))
      setTimeout(() => window.location.reload(), 800)
    } else {
      this.showError([...failures, ...notes].join("\n"))
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
