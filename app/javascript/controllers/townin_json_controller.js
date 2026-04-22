import { Controller } from "@hotwired/stimulus"

/**
 * Townin JSON 붙여넣기 컨트롤러
 * - Townin 마스터 화면의 "전체 4필드 JSON 복사"로 클립보드에 담긴 JSON을 파싱해
 *   imPD 폼 4필드(towningraph_user_id, townin_email, townin_name, townin_role)에 자동 채움.
 * - 키 변형도 허용(towningraphUserId, user_id, userId, email, name, displayName, role).
 */
export default class extends Controller {
  static targets = ["textarea", "status"]

  // ID 매핑 — 폼의 <input>에 부여된 id
  get fieldMap() {
    return {
      towningraph_user_id: "townin-user-id",
      townin_email: "townin-email",
      townin_name: "townin-name",
      townin_role: "townin-role",
    }
  }

  // 키 alias — Townin 쪽에서 스키마 바뀌어도 수용
  normalize(raw) {
    const pick = (...keys) => {
      for (const k of keys) {
        if (raw[k] !== undefined && raw[k] !== null && raw[k] !== "") return String(raw[k])
      }
      return ""
    }
    return {
      towningraph_user_id: pick("towningraph_user_id", "towningraphUserId", "user_id", "userId", "id", "uuid"),
      townin_email: pick("townin_email", "towninEmail", "email"),
      townin_name: pick("townin_name", "towninName", "name", "display_name", "displayName"),
      townin_role: pick("townin_role", "towninRole", "role"),
    }
  }

  async pasteFromClipboard() {
    this.hideStatus()
    try {
      const text = await navigator.clipboard.readText()
      if (!text || !text.trim()) {
        this.showStatus("❌ 클립보드가 비어있습니다. Townin 화면에서 '전체 4필드 JSON 복사'를 먼저 눌러주세요.", "error")
        return
      }
      this.textareaTarget.value = text.trim()
      this.applyFromTextarea()
    } catch (err) {
      this.showStatus("❌ 클립보드 읽기 실패(권한). 아래 박스에 직접 붙여넣기(Cmd+V) 후 '✓ 이 JSON 적용'을 눌러주세요: " + err.message, "error")
    }
  }

  applyFromTextarea() {
    this.hideStatus()
    const raw = this.textareaTarget.value.trim()
    if (!raw) {
      this.showStatus("❌ JSON을 입력해주세요.", "error")
      return
    }
    let parsed
    try {
      parsed = JSON.parse(raw)
    } catch (e) {
      this.showStatus(`❌ JSON 파싱 실패: ${e.message}`, "error")
      return
    }
    if (typeof parsed !== "object" || Array.isArray(parsed) || parsed === null) {
      this.showStatus("❌ 객체 형태 JSON이어야 합니다 ({ ... }).", "error")
      return
    }

    const values = this.normalize(parsed)
    const filled = []
    for (const [fieldName, domId] of Object.entries(this.fieldMap)) {
      const el = document.getElementById(domId)
      if (!el) continue
      if (values[fieldName]) {
        el.value = values[fieldName]
        this.flash(el)
        filled.push(fieldName)
      }
    }

    if (filled.length === 0) {
      this.showStatus("⚠️ 4개 필드 중 매칭된 값이 없습니다. 키 이름 확인: towningraph_user_id / townin_email / townin_name / townin_role", "error")
    } else {
      this.showStatus(`✓ ${filled.length}/4 필드 자동 채움 완료. 아래 '저장' 버튼을 눌러 확정하세요.`, "success")
      // textarea는 지워서 깔끔하게
      this.textareaTarget.value = ""
    }
  }

  clearFields() {
    for (const domId of Object.values(this.fieldMap)) {
      const el = document.getElementById(domId)
      if (el) el.value = ""
    }
    this.textareaTarget.value = ""
    this.showStatus("필드가 모두 비워졌습니다.", "info")
  }

  flash(el) {
    const prev = el.style.backgroundColor
    el.style.transition = "background-color 250ms ease"
    el.style.backgroundColor = "#fef3c7"
    setTimeout(() => { el.style.backgroundColor = prev || "" }, 900)
  }

  showStatus(msg, kind = "info") {
    const el = this.statusTarget
    el.textContent = msg
    el.classList.remove("hidden")
    el.className = el.className.replace(/text-(amber|red|green|blue)-\d+/g, "").trim()
    const colorClass = kind === "success" ? "text-green-700"
                    : kind === "error"   ? "text-red-600"
                    : "text-amber-700"
    el.classList.add(colorClass, "hidden")
    el.classList.remove("hidden")
  }

  hideStatus() {
    if (this.hasStatusTarget) this.statusTarget.classList.add("hidden")
  }
}
