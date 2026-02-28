import { Controller } from "@hotwired/stimulus"

// 예약 폼: 시작/종료 시간 유효성 + 종료 시간 자동 설정
// 사용법:
//   <form data-controller="reservation-form">
//     <input type="time" data-reservation-form-target="startTime" data-action="change->reservation-form#onStartChange">
//     <input type="time" data-reservation-form-target="endTime">
//     <span data-reservation-form-target="durationDisplay"></span>
//   </form>
export default class extends Controller {
  static targets = ["startTime", "endTime", "durationDisplay", "submitBtn"]

  connect() {
    this.validate()
  }

  onStartChange() {
    // 종료 시간이 비어있으면 시작+1시간으로 자동 설정
    if (this.hasStartTimeTarget && this.hasEndTimeTarget) {
      const start = this.startTimeTarget.value
      if (start && !this.endTimeTarget.value) {
        const [h, m] = start.split(":").map(Number)
        const endHour = Math.min(h + 1, 23)
        this.endTimeTarget.value = `${String(endHour).padStart(2, "0")}:${String(m).padStart(2, "0")}`
      }
      this.updateDuration()
      this.validate()
    }
  }

  onEndChange() {
    this.updateDuration()
    this.validate()
  }

  updateDuration() {
    if (!this.hasStartTimeTarget || !this.hasEndTimeTarget || !this.hasDurationDisplayTarget) return

    const start = this.startTimeTarget.value
    const end   = this.endTimeTarget.value
    if (!start || !end) return

    const [sh, sm] = start.split(":").map(Number)
    const [eh, em] = end.split(":").map(Number)
    const minutes  = (eh * 60 + em) - (sh * 60 + sm)

    if (minutes > 0) {
      const h = Math.floor(minutes / 60)
      const m = minutes % 60
      this.durationDisplayTarget.textContent = h > 0
        ? `${h}시간 ${m > 0 ? m + "분" : ""}`
        : `${m}분`
      this.durationDisplayTarget.classList.remove("text-red-500")
      this.durationDisplayTarget.classList.add("text-gray-500")
    } else {
      this.durationDisplayTarget.textContent = "종료 시간이 시작 시간보다 늦어야 합니다"
      this.durationDisplayTarget.classList.add("text-red-500")
      this.durationDisplayTarget.classList.remove("text-gray-500")
    }
  }

  validate() {
    if (!this.hasStartTimeTarget || !this.hasEndTimeTarget || !this.hasSubmitBtnTarget) return
    const start = this.startTimeTarget.value
    const end   = this.endTimeTarget.value
    if (start && end) {
      const valid = end > start
      this.submitBtnTarget.disabled = !valid
      this.submitBtnTarget.classList.toggle("opacity-50", !valid)
    }
  }
}
