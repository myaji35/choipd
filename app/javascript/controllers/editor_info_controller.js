import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bio", "bioCount", "profession", "customProfession"]

  connect() {
    this.updateBioCount()
    this.toggleProfession()
  }

  updateBioCount() {
    this.bioCountTarget.textContent = Array.from(this.bioTarget.value).length
  }

  toggleProfession() {
    this.customProfessionTarget.hidden = this.professionTarget.value !== "custom"
  }
}
