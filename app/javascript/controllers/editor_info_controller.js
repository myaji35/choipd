import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bio", "bioCount", "bioHint", "profession", "customProfession", "photoStatus"]

  static values = { task: String }

  connect() {
    this.updateBioCount()
    this.toggleProfession()
  }

  uploadProfilePhoto(event) {
    const input = event.currentTarget
    if (input.files.length > 0) input.form.requestSubmit()
  }

  async submitProfilePhoto(event) {
    event.preventDefault()
    if (this.uploadingPhoto) return

    const form = event.currentTarget
    const section = form.closest("#profile-photo")
    const controls = section.querySelectorAll('button:not(:disabled), input[type="file"]:not(:disabled)')
    this.uploadingPhoto = true
    this.showPhotoStatus("사진을 올리는 중이에요…")

    try {
      const body = new FormData(form, event.submitter)
      controls.forEach(control => {
        control.disabled = true
        control.setAttribute("aria-busy", "true")
      })

      const response = await fetch(form.action, {
        method: "POST",
        body,
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? "",
          "Accept": "text/html"
        },
        credentials: "same-origin",
        redirect: "follow"
      })
      if (!response.ok) throw new Error()

      const page = new DOMParser().parseFromString(await response.text(), "text/html")
      const updatedSection = page.querySelector("#profile-photo")
      if (!updatedSection) {
        window.location.assign(response.url)
        return
      }

      section.replaceWith(document.importNode(updatedSection, true))
      if (!updatedSection.querySelector(".profile-photo-error")) {
        this.showPhotoStatus("프로필 사진을 바꿨어요. 아래에 쓰던 글은 그대로예요.")
      }
    } catch {
      const input = form.querySelector('input[type="file"]')
      if (input) input.value = ""
      this.showPhotoStatus("사진을 올리지 못했어요. 인터넷 연결을 확인하고 다시 눌러 주세요.")
    } finally {
      this.uploadingPhoto = false
      controls.forEach(control => {
        control.disabled = false
        control.removeAttribute("aria-busy")
      })
    }
  }

  showPhotoStatus(message) {
    if (!this.hasPhotoStatusTarget) return

    this.photoStatusTarget.hidden = false
    this.photoStatusTarget.textContent = message
  }

  updateBioCount() {
    const count = Array.from(this.bioTarget.value).length
    this.bioCountTarget.textContent = count
    if (!this.hasBioHintTarget) return

    if (this.taskValue === "bio") {
      this.bioHintTarget.textContent = count < 50 ? `${50 - count}자만 더 쓰면 이 할 일이 끝나요.` : "충분해요."
    } else if (count < 20) {
      this.bioHintTarget.textContent = "20자를 넘기면 내 페이지를 공개할 수 있어요."
    } else if (count < 50) {
      this.bioHintTarget.textContent = "공개할 수 있어요. 50자를 넘기면 준비 항목 '자기소개'가 채워져요."
    } else {
      this.bioHintTarget.textContent = "충분해요."
    }
  }

  toggleProfession() {
    this.customProfessionTarget.hidden = this.professionTarget.value !== "custom"
  }
}
