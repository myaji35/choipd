import { Controller } from "@hotwired/stimulus"

// 칸반 보드 — 드래그앤드롭 + 카드/컬럼 CRUD
export default class extends Controller {
  static values = {
    projectId: Number,
    csrf: String,
    moveUrl: String,
    createTaskUrl: String,
    deleteTaskUrl: String,
    createColumnUrl: String
  }

  connect() {
    this.bindDragHandlers()
  }

  bindDragHandlers() {
    const cards = this.element.querySelectorAll(".kanban-card")
    const columns = this.element.querySelectorAll(".kanban-tasks")

    cards.forEach(card => {
      card.addEventListener("dragstart", (e) => {
        card.classList.add("dragging")
        e.dataTransfer.setData("task-id", card.dataset.taskId)
        e.dataTransfer.effectAllowed = "move"
      })
      card.addEventListener("dragend", () => card.classList.remove("dragging"))
    })

    columns.forEach(col => {
      col.addEventListener("dragover", (e) => {
        e.preventDefault()
        col.classList.add("drag-over")
        const dragging = this.element.querySelector(".dragging")
        if (!dragging) return
        const after = this.getDragAfterElement(col, e.clientY)
        if (after == null) {
          col.appendChild(dragging)
        } else {
          col.insertBefore(dragging, after)
        }
      })
      col.addEventListener("dragleave", () => col.classList.remove("drag-over"))
      col.addEventListener("drop", async (e) => {
        e.preventDefault()
        col.classList.remove("drag-over")
        const taskId = e.dataTransfer.getData("task-id")
        const newColumnId = col.dataset.columnId
        const orderedIds = [...col.querySelectorAll(".kanban-card")].map(c => Number(c.dataset.taskId))

        await this.api(this.moveUrlValue.replace("__ID__", taskId), {
          method: "POST",
          body: JSON.stringify({ column_id: newColumnId, ordered_ids: orderedIds })
        })
      })
    })
  }

  getDragAfterElement(container, y) {
    const cards = [...container.querySelectorAll(".kanban-card:not(.dragging)")]
    return cards.reduce((closest, child) => {
      const box = child.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      if (offset < 0 && offset > closest.offset) return { offset, element: child }
      return closest
    }, { offset: Number.NEGATIVE_INFINITY }).element
  }

  async openCreateTask(e) {
    const columnId = e.currentTarget.dataset.columnId
    const title = prompt("카드 제목:")
    if (!title) return
    const data = await this.api(this.createTaskUrlValue, {
      method: "POST",
      body: JSON.stringify({ column_id: columnId, title })
    })
    if (data?.success) location.reload()
  }

  async deleteTask(e) {
    const taskId = e.currentTarget.dataset.taskId
    if (!confirm("카드를 삭제하시겠습니까?")) return
    const data = await this.api(this.deleteTaskUrlValue.replace("__ID__", taskId), { method: "DELETE" })
    if (data?.success) e.currentTarget.closest(".kanban-card").remove()
  }

  async completeTask(e) {
    const taskId = e.currentTarget.dataset.taskId
    const url = this.deleteTaskUrlValue.replace("__ID__", taskId).replace(/\/?$/, "/complete")
    const data = await this.api(url, { method: "POST" })
    if (data?.success) location.reload()
  }

  async reopenTask(e) {
    const taskId = e.currentTarget.dataset.taskId
    const url = this.deleteTaskUrlValue.replace("__ID__", taskId).replace(/\/?$/, "/reopen")
    const data = await this.api(url, { method: "POST" })
    if (data?.success) location.reload()
  }

  async openCreateColumn() {
    const title = prompt("컬럼 이름:")
    if (!title) return
    const data = await this.api(this.createColumnUrlValue, {
      method: "POST",
      body: JSON.stringify({ title })
    })
    if (data?.success) location.reload()
  }

  async api(url, opts = {}) {
    try {
      const res = await fetch(url, {
        ...opts,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfValue
        }
      })
      return await res.json()
    } catch (e) {
      console.error("[kanban]", e)
      return null
    }
  }
}
