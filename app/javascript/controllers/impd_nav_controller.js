import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel", "menuIcon", "closeIcon"]

  toggle() {
    this.setOpen(this.panelTarget.hidden)
  }

  close() {
    this.setOpen(false)
  }

  closeOnLink(event) {
    if (event.target.closest("a")) this.close()
  }

  setOpen(open) {
    this.panelTarget.hidden = !open
    this.menuIconTarget.hidden = open
    this.closeIconTarget.hidden = !open
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.setAttribute("aria-label", open ? "메뉴 닫기" : "메뉴 열기")
  }
}
