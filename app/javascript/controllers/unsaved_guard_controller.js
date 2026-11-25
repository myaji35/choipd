import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.dirty = this.element.querySelector('[aria-invalid="true"], [data-unsaved-guard-error]') !== null
    this.submitting = false
    this.markDirty = () => { this.dirty = true }
    this.startSubmit = () => { this.submitting = true }
    this.endSubmit = this.endSubmit.bind(this)
    this.beforeUnload = this.beforeUnload.bind(this)
    this.beforeVisit = this.beforeVisit.bind(this)

    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("change", this.markDirty)
    this.element.addEventListener("submit", this.startSubmit)
    this.element.addEventListener("turbo:submit-end", this.endSubmit)
    window.addEventListener("beforeunload", this.beforeUnload)
    document.addEventListener("turbo:before-visit", this.beforeVisit)
  }

  disconnect() {
    this.element.removeEventListener("input", this.markDirty)
    this.element.removeEventListener("change", this.markDirty)
    this.element.removeEventListener("submit", this.startSubmit)
    this.element.removeEventListener("turbo:submit-end", this.endSubmit)
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
  }

  endSubmit(event) {
    this.submitting = false
    if (event.detail.success) this.dirty = false
  }

  beforeUnload(event) {
    if (!this.dirty || this.submitting) return

    event.preventDefault()
    event.returnValue = ""
  }

  beforeVisit(event) {
    if (!this.dirty || this.submitting || event.defaultPrevented) return

    event.unsavedGuardAnswer ??= window.confirm("아직 저장하지 않은 내용이 있어요.\n이 화면을 떠나면 쓴 내용이 사라져요. 그래도 떠날까요?")
    if (event.unsavedGuardAnswer) {
      this.dirty = false
    } else {
      event.preventDefault()
    }
  }
}
