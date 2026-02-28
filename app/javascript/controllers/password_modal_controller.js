import { Controller } from "@hotwired/stimulus"

// 예약 수정/삭제 시 비밀번호 확인 모달
// 사용법:
//   <div data-controller="password-modal">
//     <button data-action="password-modal#open" data-password-modal-url-param="/reservations/1/verify">수정</button>
//     <div data-password-modal-target="modal" class="hidden">...</div>
//   </div>
export default class extends Controller {
  static targets = ["modal", "overlay"]
  static values = { url: String }

  open(event) {
    event.preventDefault()
    const url = event.params?.url || event.currentTarget.dataset.url
    if (url) {
      window.location.href = url
    } else if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      this.overlayTarget?.classList.remove("hidden")
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      this.overlayTarget?.classList.add("hidden")
    }
  }

  // 모달 바깥 클릭 시 닫기
  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }
}
