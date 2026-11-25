import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bio", "bioCount", "bioHint", "profession", "customProfession"]

  connect() {
    this.updateBioCount()
    this.toggleProfession()
  }

  uploadProfilePhoto(event) {
    const input = event.currentTarget
    if (input.files.length > 0) input.form.requestSubmit()
  }

  updateBioCount() {
    const count = Array.from(this.bioTarget.value).length
    this.bioCountTarget.textContent = count
    if (!this.hasBioHintTarget) return

    if (count < 20) {
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
