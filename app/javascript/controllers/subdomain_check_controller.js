import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "status", "submit" ]
  static values = { url: String, minLength: Number }

  connect() {
    this.timeout = null
    this.check()
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  queue() {
    if (this.timeout) clearTimeout(this.timeout)
    this.renderStatus("확인 중...", "text-gray-500")
    this.timeout = setTimeout(() => this.check(), 250)
  }

  check() {
    const candidate = this.inputTarget.value.trim().toLowerCase()
    const minLength = this.hasMinLengthValue ? this.minLengthValue : 3

    if (candidate.length < minLength) {
      this.toggleSubmit(false)
      this.renderStatus(`서브도메인은 최소 ${minLength}자 이상이어야 합니다.`, "text-amber-600")
      return
    }

    const url = `${this.urlValue}?subdomain=${encodeURIComponent(candidate)}`
    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.ok ? response.json() : Promise.reject(response))
      .then((data) => {
        if (data.available) {
          this.toggleSubmit(true)
          this.renderStatus(data.message, "text-emerald-600")
        } else {
          this.toggleSubmit(false)
          this.renderStatus(data.message, "text-red-600")
        }
      })
      .catch(() => {
        this.toggleSubmit(true)
        this.renderStatus("가용성 확인에 실패했습니다. 제출 시 서버에서 다시 검증합니다.", "text-amber-600")
      })
  }

  toggleSubmit(enabled) {
    if (this.hasSubmitTarget) this.submitTarget.disabled = !enabled
  }

  renderStatus(message, classes) {
    if (!this.hasStatusTarget) return
    this.statusTarget.className = `text-xs mt-1 ${classes}`
    this.statusTarget.textContent = message
  }
}
