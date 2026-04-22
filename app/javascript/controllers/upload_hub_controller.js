import { Controller } from "@hotwired/stimulus"

// Tab switcher for editor upload hub (docs / media)
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.show("docs")
  }

  switch(event) {
    const id = event.currentTarget.dataset.uploadHubTabParam
    this.show(id)
  }

  show(id) {
    this.tabTargets.forEach(btn => {
      const active = btn.dataset.tabId === id
      btn.style.background = active ? "var(--impd-ink)" : "transparent"
      btn.style.color = active ? "var(--impd-paper)" : "var(--impd-ink)"
      btn.querySelectorAll(".impd-label").forEach(el => {
        el.style.color = active ? "rgba(255,255,255,0.55)" : "var(--impd-accent)"
      })
      btn.querySelectorAll("div:nth-child(3)").forEach(el => {
        el.style.color = active ? "rgba(255,255,255,0.55)" : "var(--impd-muted)"
      })
    })
    this.panelTargets.forEach(panel => {
      panel.style.display = panel.dataset.panelId === id ? "block" : "none"
    })
  }
}
