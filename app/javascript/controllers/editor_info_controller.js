import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bio", "bioCount", "profession", "customProfession"]

  connect() {
    this.updateBioCount()
    this.toggleProfession()
  }

  uploadProfilePhoto(event) {
    const input = event.currentTarget
    if (input.files.length > 0) input.form.requestSubmit()
  }

  updateBioCount() {
    this.bioCountTarget.textContent = Array.from(this.bioTarget.value).length
  }

  toggleProfession() {
    this.customProfessionTarget.hidden = this.professionTarget.value !== "custom"
  }
}
