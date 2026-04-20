import { Controller } from "@hotwired/stimulus"

// Identity Uploader — Next.js DistributorIdentityUploader.tsx 동작 포팅
export default class extends Controller {
  static targets = ["dropzone", "fileInput", "filename", "content", "error", "meta", "status", "deleteBtn"]
  static values = {
    distributorId: Number,
    showUrl: String,
    updateUrl: String,
    deleteUrl: String,
    csrf: String
  }

  connect() {
    this.loadExisting()
  }

  async loadExisting() {
    try {
      const res = await fetch(this.showUrlValue, { headers: { Accept: "application/json" } })
      const data = await res.json()
      if (data.success && data.identity) {
        this.filenameTarget.value = data.identity.filename || "identity.md"
        this.contentTarget.value = data.identity.content || ""
        if (data.identity.updatedAt) {
          this.metaTarget.textContent = `최근 저장: ${new Date(data.identity.updatedAt).toLocaleString("ko-KR")}`
        }
        if (data.identity.content) {
          this.deleteBtnTarget.classList.remove("hidden")
        }
      }
    } catch (e) {
      console.error("[identity-uploader] load failed", e)
    }
  }

  dragover(e) {
    e.preventDefault()
    this.dropzoneTarget.classList.add("border-primary", "bg-blue-50")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("border-primary", "bg-blue-50")
  }

  drop(e) {
    e.preventDefault()
    this.dropzoneTarget.classList.remove("border-primary", "bg-blue-50")
    const file = e.dataTransfer.files[0]
    if (file) this.processFile(file)
  }

  fileSelected(e) {
    const file = e.target.files[0]
    if (file) this.processFile(file)
  }

  async processFile(file) {
    const lower = file.name.toLowerCase()
    if (!/\.(md|markdown|txt)$/.test(lower)) {
      this.showError(".md / .markdown / .txt 파일만 허용됩니다.")
      return
    }
    if (file.size > 512 * 1024) {
      this.showError("파일 크기가 512KB를 초과합니다.")
      return
    }
    const text = await file.text()
    this.filenameTarget.value = file.name
    this.contentTarget.value = text
    this.hideError()
    this.statusTarget.textContent = "✓ 업로드 준비됨 (저장 버튼을 눌러주세요)"
  }

  async save() {
    this.hideError()
    this.statusTarget.textContent = "저장 중..."
    try {
      const res = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfValue
        },
        body: JSON.stringify({
          content: this.contentTarget.value,
          filename: this.filenameTarget.value || "identity.md"
        })
      })
      const data = await res.json()
      if (data.success) {
        this.statusTarget.textContent = "✓ 저장됨"
        this.metaTarget.textContent = `최근 저장: ${new Date(data.identity.updatedAt).toLocaleString("ko-KR")}`
        this.deleteBtnTarget.classList.remove("hidden")
        // Identity preview 새로고침 트리거
        document.dispatchEvent(new CustomEvent("identity:saved", { detail: data.identity }))
        // 페이지 새로고침으로 preview 즉시 반영 (간단)
        setTimeout(() => location.reload(), 500)
      } else {
        this.showError(data.error || "저장 실패")
      }
    } catch (e) {
      this.showError(`저장 중 오류: ${e.message}`)
    }
  }

  async deleteIdentity() {
    if (!confirm("Identity 문서를 삭제하시겠습니까?")) return
    try {
      const res = await fetch(this.deleteUrlValue, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfValue
        }
      })
      const data = await res.json()
      if (data.success) {
        this.contentTarget.value = ""
        this.filenameTarget.value = "identity.md"
        this.metaTarget.textContent = ""
        this.deleteBtnTarget.classList.add("hidden")
        this.statusTarget.textContent = "✓ 삭제됨"
        setTimeout(() => location.reload(), 500)
      }
    } catch (e) {
      this.showError(`삭제 실패: ${e.message}`)
    }
  }

  showError(msg) {
    this.errorTarget.textContent = msg
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.classList.add("hidden")
    this.errorTarget.textContent = ""
  }
}
