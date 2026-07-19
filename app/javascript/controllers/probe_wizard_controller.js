import { Controller } from "@hotwired/stimulus"

// ISS-402: Identity Probe Wizard (S0~S6) controller
//
// 책임
//  - S0 로딩 단계: /welcome/probe/status 폴링 + 진행 애니메이션
//  - S1~S5: 카드/칩/체크박스 선택 UX, 직접 입력 토글
//  - 키보드 내비: ← → = prev/next, Enter = next
//  - 다음 스텝으로 진행 시: PATCH /welcome/probe/step/:n with payload
//  - S6: 필수 동의 2개 검증 후에만 발행 버튼 활성
export default class extends Controller {
  static values = {
    currentStep: { type: Number, default: 0 },
    totalSteps:  { type: Number, default: 6 },
    pollUrl:     String,
    rewriteBioUrl: String,
    slug:        String,
  }

  static targets = [
    "card",
    "nextBtn",
    // S0
    "s0Sources", "s0Elapsed", "s0Hint",
    // S1
    "candidate", "s1Selected",
    // S2
    "professionChip", "regionChip",
    "professionManualBtn", "regionManualBtn",
    "professionManualInput", "regionManualInput",
    "s2Profession", "s2Region",
    // S3
    "snsRow", "snsCheckbox", "snsManualUrl", "s3Links",
    // S4
    "bioText", "bioManualBtn", "bioManualInput", "bioStatus", "s4Bio",
    // S5
    "avatarCard", "avatarFileInput", "s5Avatar",
    // S6
    "consentRow",
    "consentPublish", "consentShare", "consentAutoSync", "consentSampleUse",
    "finishBtn", "finishForm",
  ]

  connect() {
    this.selectedCandidate = null
    this.selectedProfession = null
    this.selectedRegion = null
    this.selectedLinks = []
    this.currentBio = ""
    this.bioIndex = 0
    this.selectedAvatar = null
    this.consents = { publish: true, share: true, auto_sync: false, sample_use: false }

    this._bindKeyboard()
    this._hydrateFromDom()

    if (this.currentStepValue === 0) this._startS0()
    if (this.currentStepValue === 6) this._updateFinishBtn()
  }

  disconnect() {
    this._stopS0()
    document.removeEventListener("keydown", this._onKey)
  }

  // ── 키보드 내비 ─────────────────────────────
  _bindKeyboard() {
    this._onKey = (e) => {
      if (this.currentStepValue === 0) return
      const tag = (e.target.tagName || "").toLowerCase()
      if (tag === "input" || tag === "textarea" || tag === "select") return

      if (e.key === "ArrowLeft") {
        e.preventDefault()
        this.prev()
      } else if (e.key === "ArrowRight" || e.key === "Enter") {
        e.preventDefault()
        this.next()
      }
    }
    document.addEventListener("keydown", this._onKey)
  }

  // ── DOM에서 기존 선택값 복원 (재진입 대비) ──
  _hydrateFromDom() {
    // S3: 기본 checked 행들을 selectedLinks에 편입
    if (this.hasSnsRowTarget) {
      this.snsRowTargets.forEach(row => {
        if (row.classList.contains("is-checked")) {
          try {
            const payload = JSON.parse(row.dataset.snsPayload || "{}")
            if (payload.url) this.selectedLinks.push(payload)
          } catch (_) {}
        }
      })
      this._syncS3Hidden()
    }
    // S4: 초기 bio
    if (this.hasS4BioTarget) this.currentBio = this.s4BioTarget.value
  }

  // ── S0 로딩 + 폴링 ─────────────────────────
  _startS0() {
    this.s0StartedAt = Date.now()
    this._s0Tick()
    this._s0Interval = setInterval(() => this._s0Tick(), 1000)
  }

  _stopS0() {
    if (this._s0Interval) clearInterval(this._s0Interval)
    this._s0Interval = null
  }

  async _s0Tick() {
    const elapsed = Math.round((Date.now() - this.s0StartedAt) / 1000)
    if (this.hasS0ElapsedTarget) this.s0ElapsedTarget.textContent = elapsed

    try {
      const res = await fetch(this.pollUrlValue, { headers: { Accept: "application/json" } })
      if (!res.ok) throw new Error(`status ${res.status}`)
      const data = await res.json()

      this._updateS0Sources(data.sources_hit || [])

      if (data.status === "completed") {
        this._stopS0()
        this._advanceTo(1)
      } else if (data.status === "failed" || data.status === "expired") {
        this._stopS0()
        // 실패해도 S1 수동 입력 모드로 진행
        this._advanceTo(1)
      } else if (elapsed > 30) {
        // 30초 넘게 안 끝나면 그냥 S1로 (백엔드 미완성 대비)
        this._stopS0()
        this._advanceTo(1)
      }
    } catch (err) {
      // 폴링 실패는 조용히 로그만
      if (elapsed > 20) {
        this._stopS0()
        this._advanceTo(1)
      }
    }
  }

  _updateS0Sources(hitList) {
    if (!this.hasS0SourcesTarget) return
    const hits = new Set(hitList)
    this.s0SourcesTarget.querySelectorAll("[data-source-key]").forEach(li => {
      const k = li.dataset.sourceKey
      const icon = li.querySelector("[data-source-icon]")
      const check = icon && icon.querySelector("svg")
      if (hits.has(k)) {
        li.style.color = "var(--impd-ink)"
        if (icon) { icon.style.borderColor = "#10B981"; icon.style.background = "rgba(16,185,129,0.1)" }
        if (check) check.style.opacity = "1"
      }
    })
  }

  // ── 내비: next/prev/skip ───────────────────
  prev() {
    const step = this.currentStepValue
    if (step <= 1) return
    Turbo.visit(`/welcome/probe?step=${step - 1}`)
  }

  next() {
    const step = this.currentStepValue
    if (step < 1 || step > 6) return

    const payload = this._collectPayload(step)
    if (payload === null) return // 검증 실패

    this._submitStep(step, payload)
  }

  _advanceTo(step) {
    Turbo.visit(`/welcome/probe?step=${step}`)
  }

  async _submitStep(step, payload) {
    // step이 유효한 정수가 아니면 서버로 쏘지 말고 클라이언트 advance로 폴백 — 과거 버그(/welcome/probe 로 PATCH) 재발 방지.
    const stepInt = parseInt(step, 10)
    if (!Number.isFinite(stepInt) || stepInt < 1 || stepInt > this.totalStepsValue) {
      console.warn("[probe_wizard] invalid step, advancing client-side", step)
      const curr = this.currentStepValue || 1
      this._advanceTo(Math.min(curr + 1, this.totalStepsValue))
      return
    }
    try {
      const csrfMeta = document.querySelector("meta[name='csrf-token']")
      const csrfToken = csrfMeta ? csrfMeta.content : ""
      const formData = new FormData()
      const safePayload = (payload && typeof payload === "object") ? payload : {}
      Object.keys(safePayload).forEach(k => {
        const v = safePayload[k]
        if (v !== null && v !== undefined && typeof v === "object") {
          formData.append(`payload[${k}]`, JSON.stringify(v))
        } else if (v !== null && v !== undefined) {
          formData.append(`payload[${k}]`, String(v))
        }
      })
      // payload가 비어도 Rails가 ParameterMissing 뜨지 않도록 sentinel 키.
      if (!formData.has(`payload[_skipped]`)) {
        // 실제 값 있는 키가 없으면 sentinel 1개를 넣는다.
        const hasAny = Array.from(formData.keys()).some(k => k.startsWith("payload["))
        if (!hasAny) formData.append("payload[_skipped]", "1")
      }

      const res = await fetch(`/welcome/probe/step/${step}`, {
        method: "PATCH",
        headers: { "X-CSRF-Token": csrfToken, "Accept": "text/html" },
        body: formData,
      })
      if (res.redirected) {
        Turbo.visit(res.url)
      } else if (res.ok) {
        // fallback: client-side advance
        this._advanceTo(Math.min(step + 1, this.totalStepsValue))
      } else {
        console.warn("[probe_wizard] step submit failed", res.status)
        this._advanceTo(Math.min(step + 1, this.totalStepsValue))
      }
    } catch (err) {
      console.warn("[probe_wizard] step submit error", err)
      this._advanceTo(Math.min(step + 1, this.totalStepsValue))
    }
  }

  // 각 스텝별 payload 수집 + 검증. null 반환 시 진행 중단.
  _collectPayload(step) {
    switch (step) {
      case 1:
        return { selected: this.selectedCandidate, rejected: !this.selectedCandidate }
      case 2: {
        const prof = this._currentProfession()
        const reg  = this._currentRegion()
        return { profession: prof || "", region: reg || "" }
      }
      case 3:
        return { links: this.selectedLinks }
      case 4: {
        const bio = this.hasBioManualInputTarget && this.bioManualInputTarget.style.display !== "none"
          ? this.bioManualInputTarget.value.trim()
          : this.currentBio
        return { bio: bio.slice(0, 180) }
      }
      case 5:
        return { source: this.selectedAvatar?.source || "initials", url: this.selectedAvatar?.url || "" }
      case 6:
        return {}
      default:
        return {}
    }
  }

  // ── S1: 후보 선택 ───────────────────────────
  selectCandidate(event) {
    const btn = event.currentTarget
    let payload = {}
    try { payload = JSON.parse(btn.dataset.candidatePayload || "{}") } catch (_) {}
    this.candidateTargets.forEach(b => {
      b.classList.remove("is-selected")
      b.setAttribute("aria-checked", "false")
    })
    btn.classList.add("is-selected")
    btn.setAttribute("aria-checked", "true")
    this.selectedCandidate = payload
    if (this.hasS1SelectedTarget) this.s1SelectedTarget.value = JSON.stringify(payload)
  }

  rejectAll() {
    // "제가 아닌 사람" — 이 probe 결과는 폐기, 바로 S2부터 빈 모드
    this.selectedCandidate = null
    this._submitStep(1, { selected: null, rejected: true, reset: true })
  }

  // ── S2: 칩 + 직접 입력 ─────────────────────
  toggleChip(event) {
    const chip = event.currentTarget
    const group = chip.dataset.chipGroup
    const targets = group === "profession" ? this.professionChipTargets : this.regionChipTargets
    targets.forEach(c => {
      c.classList.remove("is-selected")
      c.setAttribute("aria-checked", "false")
    })
    chip.classList.add("is-selected")
    chip.setAttribute("aria-checked", "true")
    if (group === "profession") {
      this.selectedProfession = chip.dataset.chipValue
      if (this.hasProfessionManualInputTarget) {
        this.professionManualInputTarget.style.display = "none"
        this.professionManualInputTarget.value = ""
      }
    } else {
      this.selectedRegion = chip.dataset.chipValue
      if (this.hasRegionManualInputTarget) {
        this.regionManualInputTarget.style.display = "none"
        this.regionManualInputTarget.value = ""
      }
    }
  }

  toggleManualProfession() {
    if (!this.hasProfessionManualInputTarget) return
    const shown = this.professionManualInputTarget.style.display !== "none"
    this.professionManualInputTarget.style.display = shown ? "none" : "block"
    if (!shown) this.professionManualInputTarget.focus()
    // 칩 선택 해제
    this.professionChipTargets.forEach(c => c.classList.remove("is-selected"))
    this.selectedProfession = null
  }

  toggleManualRegion() {
    if (!this.hasRegionManualInputTarget) return
    const shown = this.regionManualInputTarget.style.display !== "none"
    this.regionManualInputTarget.style.display = shown ? "none" : "block"
    if (!shown) this.regionManualInputTarget.focus()
    this.regionChipTargets.forEach(c => c.classList.remove("is-selected"))
    this.selectedRegion = null
  }

  _currentProfession() {
    if (this.hasProfessionManualInputTarget && this.professionManualInputTarget.value.trim()) {
      return this.professionManualInputTarget.value.trim()
    }
    return this.selectedProfession
  }
  _currentRegion() {
    if (this.hasRegionManualInputTarget && this.regionManualInputTarget.value.trim()) {
      return this.regionManualInputTarget.value.trim()
    }
    return this.selectedRegion
  }

  // ── S3: SNS 체크박스 ────────────────────────
  toggleCheck(event) {
    // label onclick이 checkbox toggle과 겹치지 않도록 수동 관리
    const row = event.currentTarget
    if (event.target.tagName === "INPUT") return // 내부 checkbox 직접 클릭은 무시
    const isChecked = row.classList.toggle("is-checked")
    const cb = row.querySelector("[data-probe-wizard-target='snsCheckbox']")
    if (cb) cb.checked = isChecked

    let payload = {}
    try { payload = JSON.parse(row.dataset.snsPayload || "{}") } catch (_) {}
    if (isChecked) {
      if (!this.selectedLinks.find(l => l.url === payload.url)) this.selectedLinks.push(payload)
    } else {
      this.selectedLinks = this.selectedLinks.filter(l => l.url !== payload.url)
    }
    this._syncS3Hidden()
  }

  addSnsLink() {
    if (!this.hasSnsManualUrlTarget) return
    const url = this.snsManualUrlTarget.value.trim()
    if (!url) return
    const payload = { platform: "manual", url, handle: url, confidence: 100, manual: true }
    this.selectedLinks.push(payload)
    this.snsManualUrlTarget.value = ""
    this._syncS3Hidden()

    // 시각 피드백: 간단한 row를 DOM에 prepend
    const container = this.snsManualUrlTarget.closest(".probe-card") || this.element
    const host = this.snsRowTargets[0]?.parentElement
    if (host) {
      const tmp = document.createElement("div")
      tmp.innerHTML = `<label class="probe-check-row is-checked"><span class="probe-check-box"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></span><div class="probe-check-body"><div class="probe-check-title">${url}<span style="font-family: var(--impd-font-mono); font-size: 10px; color: var(--impd-muted); margin-left: 6px;">직접 추가</span></div></div></label>`
      const el = tmp.firstElementChild
      host.appendChild(el)
    }
  }

  _syncS3Hidden() {
    if (this.hasS3LinksTarget) this.s3LinksTarget.value = JSON.stringify(this.selectedLinks)
  }

  // ── S4: Bio 재작성 + 직접 쓰기 ─────────────
  async rewriteBio() {
    try {
      const csrfMeta = document.querySelector("meta[name='csrf-token']")
      const csrfToken = csrfMeta ? csrfMeta.content : ""
      const res = await fetch(this.rewriteBioUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken, "Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded" },
        body: `index=${this.bioIndex}`,
      })
      if (!res.ok) throw new Error(`status ${res.status}`)
      const data = await res.json()
      this.currentBio = data.bio
      this.bioIndex = data.index || 0
      if (this.hasBioTextTarget) this.bioTextTarget.textContent = data.bio
      if (this.hasS4BioTarget) this.s4BioTarget.value = data.bio
      if (this.hasBioStatusTarget) {
        this.bioStatusTarget.textContent = `variation ${(data.index || 0) + 1} / ${data.total || 3} · 180자 이하`
      }
      if (this.hasBioManualInputTarget) this.bioManualInputTarget.value = data.bio
    } catch (err) {
      console.warn("[probe_wizard] rewriteBio error", err)
    }
  }

  toggleBioManual() {
    if (!this.hasBioManualInputTarget) return
    const shown = this.bioManualInputTarget.style.display !== "none"
    this.bioManualInputTarget.style.display = shown ? "none" : "block"
    if (!shown) {
      this.bioManualInputTarget.focus()
      this.bioManualInputTarget.addEventListener("input", () => {
        const v = this.bioManualInputTarget.value
        this.currentBio = v
        if (this.hasBioTextTarget) this.bioTextTarget.textContent = v
        if (this.hasS4BioTarget) this.s4BioTarget.value = v
      })
    }
  }

  // ── S5: 아바타 선택 + 업로드 ──────────────
  selectAvatar(event) {
    const card = event.currentTarget
    this.avatarCardTargets.forEach(c => {
      c.classList.remove("is-selected")
      c.setAttribute("aria-checked", "false")
    })
    card.classList.add("is-selected")
    card.setAttribute("aria-checked", "true")
    this.selectedAvatar = { source: card.dataset.avatarSource, url: card.dataset.avatarUrl }
    if (this.hasS5AvatarTarget) this.s5AvatarTarget.value = JSON.stringify(this.selectedAvatar)

    // 업로드 카드 선택 시 파일 다이얼로그 오픈
    if (card.dataset.avatarSource === "upload") {
      const input = card.querySelector("[data-probe-wizard-target='avatarFileInput']")
      if (input) input.click()
    }
  }

  uploadAvatar(event) {
    const file = event.target.files && event.target.files[0]
    if (!file) return
    // 실제 업로드 엔드포인트는 별도 이슈 — 여기서는 data URL로 즉시 미리보기만.
    const reader = new FileReader()
    reader.onload = (e) => {
      const url = e.target.result
      this.selectedAvatar = { source: "upload", url }
      if (this.hasS5AvatarTarget) this.s5AvatarTarget.value = JSON.stringify(this.selectedAvatar)
      // 카드 미리보기 갱신
      const card = event.target.closest("[data-probe-wizard-target='avatarCard']")
      if (card) {
        const preview = card.querySelector(".probe-avatar-preview")
        if (preview) preview.innerHTML = `<img src="${url}" alt="" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`
      }
    }
    reader.readAsDataURL(file)
  }

  // ── S6: 동의 체크 + 발행 ───────────────────
  toggleConsent(event) {
    const row = event.currentTarget
    if (event.target.tagName === "INPUT") return
    event.preventDefault()
    const key = row.dataset.consentKey
    const isChecked = row.classList.toggle("is-checked")
    this.consents[key] = isChecked
    this._syncConsentHidden(key, isChecked)
    this._updateFinishBtn()
  }

  _syncConsentHidden(key, isChecked) {
    const map = {
      publish:     "hasConsentPublishTarget",
      share:       "hasConsentShareTarget",
      auto_sync:   "hasConsentAutoSyncTarget",
      sample_use:  "hasConsentSampleUseTarget",
    }
    const hiddenKey = {
      publish:    "consentPublishTarget",
      share:      "consentShareTarget",
      auto_sync:  "consentAutoSyncTarget",
      sample_use: "consentSampleUseTarget",
    }[key]
    if (!hiddenKey) return
    if (this[map[key]]) {
      this[hiddenKey].value = isChecked ? "1" : "0"
    }
  }

  _updateFinishBtn() {
    if (!this.hasFinishBtnTarget) return
    const ok = this.consents.publish && this.consents.share
    if (ok) {
      this.finishBtnTarget.classList.remove("is-disabled")
      this.finishBtnTarget.removeAttribute("disabled")
    } else {
      this.finishBtnTarget.classList.add("is-disabled")
      this.finishBtnTarget.setAttribute("disabled", "disabled")
    }
  }

  confirmFinal(event) {
    if (!(this.consents.publish && this.consents.share)) {
      event.preventDefault()
      return false
    }
    // 간단한 confetti 이펙트
    this._confetti()
    // form submit은 기본 동작으로 진행
  }

  _confetti() {
    try {
      const host = document.createElement("div")
      host.style.cssText = "position:fixed;inset:0;pointer-events:none;z-index:9999;overflow:hidden;"
      document.body.appendChild(host)
      const colors = ["#3a2af0", "#ff5a1f", "#00A1E0", "#10B981", "#F59E0B"]
      for (let i = 0; i < 40; i++) {
        const dot = document.createElement("span")
        const c = colors[i % colors.length]
        const left = Math.random() * 100
        const dur = 1200 + Math.random() * 600
        const delay = Math.random() * 200
        dot.style.cssText = `position:absolute;top:-10px;left:${left}%;width:8px;height:8px;background:${c};border-radius:2px;transform:rotate(${Math.random()*360}deg);opacity:0.9;transition:transform ${dur}ms ease-in,top ${dur}ms ease-in;`
        host.appendChild(dot)
        requestAnimationFrame(() => {
          setTimeout(() => {
            dot.style.top = "100%"
            dot.style.transform = `translateX(${(Math.random()-0.5)*200}px) rotate(${Math.random()*720}deg)`
          }, delay)
        })
      }
      setTimeout(() => host.remove(), 1800)
    } catch (_) {}
  }
}
