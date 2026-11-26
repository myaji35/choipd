import { Controller } from "@hotwired/stimulus"

const IMAGE_MAX_BYTES = 25 * 1024 * 1024   // 서버 이미지 한도
const COMPRESS_TARGET_BYTES = 20 * 1024 * 1024  // 압축 목표(한도 여유 5MB)
const COMPRESS_MAX_SIDE = 3840             // 최대 긴 변 픽셀 (4K)

function errorMessage(data, status) {
  if (data?.message) return data.message
  if (data?.error === "NO_FILE") return "파일을 골라 주세요."
  if (status === 413) return "파일이 너무 커요. 사진은 25MB, 영상은 100MB까지 올릴 수 있어요."
  if (status === 0) return "인터넷 연결을 확인한 뒤 다시 해 주세요."
  return "올리지 못했어요. 잠시 뒤 다시 해 주세요."
}

// 브라우저에서 이미지 자동 압축.
// 큰 카톡 사진(30~60MB JPEG/HEIC)을 Canvas로 리사이즈 + 품질 조정해 20MB 이하로 변환.
// HEIC 는 Safari 외 브라우저가 디코딩 못 할 수 있음 → 원본 반환하고 안내.
async function compressIfNeeded(file, onProgress) {
  if (!file.type.startsWith("image/")) return { file, compressed: false }
  if (file.size <= IMAGE_MAX_BYTES) return { file, compressed: false }

  const isHeic = /heic|heif/i.test(file.type) || /\.(heic|heif)$/i.test(file.name)

  onProgress?.(`${file.name} 크기를 줄이는 중…`)
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
    onProgress?.(`${file.name} 크기를 줄였어요.`)
    return { file: compressed, compressed: true }
  } catch (err) {
    const hint = isHeic ? " 아이폰이라면 설정 > 카메라 > 포맷에서 ‘높은 호환성’을 선택하고 다시 찍어 주세요." : ""
    return { file, compressed: false, note: `사진 크기를 줄이지 못했어요.${hint}` }
  }
}

function loadImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload  = () => { URL.revokeObjectURL(url); resolve(img) }
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("사진을 읽지 못했어요.")) }
    img.src = url
  })
}
function canvasToBlob(canvas, type, quality) {
  return new Promise(resolve => canvas.toBlob(resolve, type, quality))
}

export default class extends Controller {
  static targets = ["cameraInput", "galleryInput", "category", "error", "status", "progress", "progressBar"]
  static values = { createUrl: String, csrf: String, doneUrl: String }

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
      this.statusTarget.textContent = `${original.name} 준비하는 중… (${i + 1}/${total})`
      this.setProgress(Math.round((i / total) * 100))

      // 25MB 초과 이미지는 자동 리사이즈 + 품질 조정
      const { file, compressed, note } = await compressIfNeeded(original, msg => {
        this.statusTarget.textContent = `${msg} (${i + 1}/${total})`
      })
      if (note) notes.push(`${original.name}: ${note}`)

      this.statusTarget.textContent = `${file.name} 올리는 중… (${i + 1}/${total})${compressed ? " · 크기를 줄였어요" : ""}`
      const result = await this.uploadOne(file, category)
      if (result.ok) ok++
      else failures.push(`${file.name}: ${result.error}`)
    }
    this.setProgress(100)

    if (failures.length === 0) {
      this.statusTarget.textContent = `${ok}장 올렸어요.${notes.length ? ` 안내 ${notes.length}건` : ""}`
      if (notes.length) this.showError(notes.join("\n"))
      setTimeout(() => {
        if (this.doneUrlValue) {
          const url = new URL(this.doneUrlValue, window.location.href)
          url.searchParams.set("done", "photos")
          window.location.assign(url)
        } else {
          window.location.reload()
        }
      }, 800)
    } else {
      this.showError([...failures, ...notes].join("\n"))
      if (ok > 0) {
        this.statusTarget.textContent = `${ok}개 올렸고 ${failures.length}개는 올리지 못했어요. 새로고침하면 확인할 수 있어요.`
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
      return { ok: false, error: err.message || "인터넷 연결을 확인한 뒤 다시 해 주세요." }
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
