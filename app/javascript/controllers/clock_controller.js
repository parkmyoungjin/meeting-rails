import { Controller } from "@hotwired/stimulus"

// 실시간 시계 표시 (로비/예약 인덱스 화면용)
// 사용법: <div data-controller="clock"><span data-clock-target="display"></span></div>
export default class extends Controller {
  static targets = ["display"]

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  update() {
    const now = new Date()
    const timeStr = now.toLocaleTimeString("ko-KR", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false
    })
    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = timeStr
    }
  }
}
