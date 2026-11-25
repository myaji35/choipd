import { Controller } from "@hotwired/stimulus"

// Tab switcher for editor upload hub (docs / media)
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const hash = window.location.hash.slice(1)
    const initialTab = new URLSearchParams(window.location.search).get("tab")
    const id = [initialTab, hash].find(tab => tab === "media" || tab === "docs") || "docs"
    const panel = this.panelTargets.find(target => target.dataset.panelId === id)
    const scrollToPanel = hash === id && panel.hidden
    this.show(id)
    if (scrollToPanel) panel.scrollIntoView()
  }

  switch(event) {
    const id = event.currentTarget.dataset.uploadHubTabParam
    this.show(id)
  }

  show(id) {
    this.tabTargets.forEach(btn => {
      const active = btn.dataset.tabId === id
      btn.setAttribute("aria-pressed", active)
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
      panel.hidden = panel.dataset.panelId !== id
    })
  }
}
