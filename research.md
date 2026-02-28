# Research — 회의실 예약 SaaS (meeting-rails) 설계 분석

> PLAN.md 정독 후 구현 전 파악해야 할 핵심 사항, 설계 결정의 근거, 잠재적 이슈,
> 그리고 각 Phase별 구현 지침을 정리한 문서.

---

## 1. 멀티테넌시 전략 분석

### 1-1. 서브도메인 기반 라우팅
- **선택 이유**: URL로 테넌트를 식별하면 쿠키/세션 격리가 자동으로 이루어짐. 각 병원이 `hospital-a.myapp.com` 같은 브랜딩 URL을 가짐.
- **로컬 개발 이슈 (중요)**: 브라우저는 `localhost`의 서브도메인(`demo.localhost`)을 기본적으로 지원하지 않음.
  - **해결책 A**: `/etc/hosts`(Windows: `C:\Windows\System32\drivers\etc\hosts`)에 `127.0.0.1 demo.localhost` 추가.
  - **해결책 B**: `lvh.me` 사용 — `demo.lvh.me:3000`은 DNS에서 자동으로 127.0.0.1 반환.
  - **해결책 C**: `config/application.rb`에 `config.action_dispatch.tld_length = 0` 설정하여 Rails가 `localhost`를 TLD로 인식하게 함.
  - **권장**: 옵션 C + hosts 파일 조합 사용.

- **Rails 라우팅 구현**:
  ```ruby
  # config/routes.rb
  constraints(subdomain: /.+/) do
    # request.subdomain 으로 조직 식별
  end
  ```
  `/.+/`는 빈 서브도메인(메인 도메인)을 제외하고 모든 서브도메인 매칭.

### 1-2. Row-Level Isolation vs Schema-Based
- **PLAN 선택**: Row-level (모든 테이블에 `organization_id`)
- **장점**: 마이그레이션 단순, 단일 DB 연결 풀, 조인 쿼리 용이
- **단점**: 개발자 실수로 테넌트 누수 가능 → **ApplicationController 게이트가 절대적**
- **핵심 안전망**: 모든 쿼리를 `Current.organization.rooms.find(...)` 형태로 scope 체인 강제
  ```ruby
  # 잘못된 예 (절대 금지)
  Room.find(params[:id])          # 전체 테이블 조회

  # 올바른 예
  Current.organization.rooms.find(params[:id])  # 자동 scope
  ```

### 1-3. `set_current_tenant` 구현 패턴
```ruby
# app/controllers/application_controller.rb
before_action :set_current_tenant

def set_current_tenant
  subdomain = request.subdomain
  @current_organization = Organization.find_by!(subdomain: subdomain, active: true)
  Current.organization = @current_organization
rescue ActiveRecord::RecordNotFound
  redirect_to root_url(subdomain: false), alert: "존재하지 않는 조직입니다."
end
```
- `Current` 객체: Rails 7.1+의 `ActiveSupport::CurrentAttributes` 활용
  ```ruby
  # app/models/current.rb
  class Current < ActiveSupport::CurrentAttributes
    attribute :organization, :user
  end
  ```
- `before_action`은 서브도메인 라우팅 내 컨트롤러에서만 실행되어야 함 (Landing, Registration은 제외).

---

## 2. 핵심 모델 설계 분석

### 2-1. Reservation의 `has_secure_password` (특이 설계)
- **일반적 사용**: User 모델 인증에 사용
- **이 프로젝트의 의도**: 예약 수정/삭제 시 예약자 본인 확인 (로그인 불필요한 공개 예약 시스템)
- **동작 방식**:
  ```ruby
  reservation.password = "1234"       # BCrypt로 해싱 → password_digest 저장
  reservation.authenticate("1234")    # → reservation 반환 (성공) or false (실패)
  ```
- **구현 시 주의**: `has_secure_password`는 기본적으로 `password` 필드의 존재를 강제하므로, 예약 수정 시 비밀번호 재입력 없이 다른 필드만 바꾸려면 `password: nil` 처리 로직 필요.
  ```ruby
  validates :password, length: { minimum: 4 }, allow_nil: true
  ```

### 2-2. 시간 중복 검증 (`no_time_overlap`)
```ruby
# app/models/reservation.rb
validate :no_time_overlap

def no_time_overlap
  overlapping = Reservation.where(room_id: room_id, date: date)
    .where.not(id: id)
    .where("start_time < ? AND end_time > ?", end_time, start_time)
  errors.add(:base, "해당 시간에 이미 예약이 있습니다.") if overlapping.exists?
end
```
- **Race Condition 위험**: 두 요청이 동시에 같은 시간대를 예약하면 양쪽 모두 검증을 통과할 수 있음.
- **해결책**: DB 레벨 유니크 인덱스 또는 `with_advisory_lock` gem 사용, 또는 PostgreSQL의 `FOR UPDATE` 잠금:
  ```ruby
  Reservation.where(room_id: room_id, date: date).lock.exists_overlap?
  ```
  실용적 대안: `after_create` 콜백으로 재검증 + 유니크 제약 설정.

### 2-3. Reservation의 `organization_id` 비정규화
- **이유**: `room_id`만으로는 관리자가 특정 조직의 모든 예약을 조회할 때 JOIN이 필요 → 성능 최적화
- **주의**: 저장 시 자동으로 room의 organization을 따라가도록 콜백 설정 필수
  ```ruby
  before_validation :set_organization
  def set_organization
    self.organization_id = room.organization_id if room
  end
  ```

### 2-4. Plan → Subscription 분리 설계
- **Plan**: 플랜 템플릿 (불변 데이터)
- **Subscription**: 조직별 구독 현황 (가변 데이터)
- **Organization.plan_id**: 현재 적용 중인 플랜을 빠르게 참조 (비정규화)
- 실제 권한 체크는 `subscription.status == 'active'` 확인 필요

---

## 3. 라우팅 설계 분석

### 3-1. `scope module: 'tenant'` 패턴
- PLAN에는 `scope module: 'tenant'`로 되어 있으나, 컨트롤러 디렉토리에 `tenant/` 폴더 구조가 없음.
- **실제 구현 방향**: `scope module`을 쓰지 않고 기본 컨트롤러를 사용하되, `before_action :set_current_tenant`로 테넌트 격리.
- 또는 `app/controllers/tenant/` 디렉토리를 만들고 `Tenant::ReservationsController`로 네임스페이스 분리.

### 3-2. Admin 네임스페이스
```ruby
namespace :admin do
  root 'dashboard#index'     # → Admin::DashboardController#index
  resources :rooms           # → Admin::RoomsController
  resources :reservations, only: [:index, :destroy]
  resource :subscription     # singular → Admin::SubscriptionsController (no :id)
end
```
- `resource :subscription` (singular)는 `show`, `edit`, `update`, `new`, `create`, `destroy` 생성.
- 플랜 변경 = update, 구독 취소 = destroy로 매핑.

### 3-3. Webhook 라우팅
```ruby
post '/webhooks/stripe', to: 'webhooks#stripe'
```
- **CSRF 제외 필수**: webhook은 외부에서 오는 POST 요청이므로
  ```ruby
  # WebhooksController
  protect_from_forgery except: :stripe
  ```

---

## 4. Stripe 연동 설계

### 4-1. 구독 플로우
```
조직 가입 → free 플랜 자동 적용 → 관리자가 업그레이드 선택
→ Stripe Checkout Session 생성 → 결제 완료
→ stripe webhook (checkout.session.completed) 수신
→ subscription 레코드 업데이트
```

### 4-2. Webhook 처리 핵심 (idempotency)
```ruby
# WebhooksController#stripe
def stripe
  payload = request.body.read
  sig_header = request.env['HTTP_STRIPE_SIGNATURE']

  event = Stripe::Webhook.construct_event(
    payload, sig_header, ENV['STRIPE_WEBHOOK_SECRET']
  )

  case event.type
  when 'checkout.session.completed'
    handle_checkout_completed(event.data.object)
  when 'customer.subscription.updated'
    handle_subscription_updated(event.data.object)
  when 'customer.subscription.deleted'
    handle_subscription_canceled(event.data.object)
  when 'invoice.payment_failed'
    handle_payment_failed(event.data.object)
  end

  render json: { received: true }
rescue Stripe::SignatureVerificationError
  head :bad_request
end
```
- 같은 이벤트가 여러 번 올 수 있으므로 `stripe_subscription_id`로 중복 처리 방지.

### 4-3. 플랜별 회의실 수 제한 강제
```ruby
# Admin::RoomsController#create
def create
  limit = Current.organization.plan.room_limit
  if limit && Current.organization.rooms.active.count >= limit
    redirect_to admin_rooms_path, alert: "현재 플랜(#{limit}개)의 회의실 한도에 도달했습니다."
    return
  end
  # ... 생성 로직
end
```

---

## 5. Hotwire 활용 계획

### 5-1. 예약 타임라인 뷰 (Turbo Frames)
```erb
<%# reservations/index.html.erb %>
<turbo-frame id="reservation-list" src="<%= reservations_path(date: @date, floor: @floor) %>">
  <%= render 'timeline', reservations: @reservations %>
</turbo-frame>
```
- 날짜/층 변경 시 전체 페이지 리로드 없이 해당 프레임만 업데이트.

### 5-2. Stimulus Controllers
| 컨트롤러 | 역할 |
|----------|------|
| `reservation_form_controller.js` | 시작/종료 시간 선택 UI, 중복 시간 미리보기 |
| `password_modal_controller.js` | 예약 수정/삭제 시 비밀번호 확인 모달 표시 |
| `clock_controller.js` | 현재 시간 실시간 표시 (로비 화면용) |

---

## 6. 보안 체크리스트

| 항목 | 구현 방법 |
|------|----------|
| 테넌트 격리 | 모든 쿼리를 `Current.organization` 스코프로 강제 |
| Stripe webhook 위변조 방지 | `Stripe::Webhook.construct_event` 서명 검증 |
| 예약 비밀번호 | `has_secure_password` (BCrypt) |
| 관리자 권한 분리 | `Admin::BaseController` before_action role 체크 |
| 슈퍼어드민 분리 | `/super_admin` 네임스페이스 + 별도 인증 |
| 레이트리밋 | rack-attack (로그인 시도, 예약 생성 등) |
| HTTPS 강제 | `config.force_ssl = true` (production) |
| 보안 헤더 | `config.action_dispatch.default_headers` 설정 |
| CSRF | Rails 기본 + webhook 엔드포인트 제외 |
| SQL Injection | ActiveRecord 파라미터 바인딩 사용 (자동 보호) |

---

## 7. 잠재적 리스크 및 해결 방안

### 리스크 1: 예약 생성 Race Condition
- **문제**: 동시에 같은 시간 예약 시 중복 허용 가능
- **해결**: PostgreSQL Advisory Lock 또는 `lock!` 사용, 또는 DB 레벨 제약

### 리스크 2: Stripe Webhook 미수신
- **문제**: 결제 성공 후 webhook이 늦게 오거나 누락
- **해결**: Stripe Dashboard에서 failed webhook 재전송 설정, 구독 상태 polling 보완

### 리스크 3: Subdomain Takeover
- **문제**: 탈퇴한 조직의 서브도메인을 타인이 재사용
- **해결**: `subdomain` 필드는 소프트 삭제 후에도 재사용 불가 처리 (unique 제약 유지)

### 리스크 4: 과거 날짜 예약
- **문제**: 클라이언트 시간 조작
- **해결**: `validates :date, comparison: { greater_than_or_equal_to: -> { Date.current } }` (서버 검증)

### 리스크 5: 플랜 다운그레이드 시 기존 회의실 초과
- **문제**: Basic(5개)에서 Free(2개)로 다운 시 기존 3개 회의실 처리
- **해결**: 다운그레이드 시 초과 회의실 `active: false` 처리 또는 경고 메시지 표시

---

## 8. 배포 고려사항

### Render.com
- **장점**: 설정 단순, Rails 기본 지원, 무료 PostgreSQL (개발용)
- **단점**: 무료 플랜 슬립 모드, 와일드카드 SSL 유료
- **와일드카드 서브도메인**: 커스텀 도메인 + 와일드카드 CNAME 필요

### Fly.io
- **장점**: 글로벌 엣지 배포, 더 많은 제어권, 와일드카드 도메인 지원
- **단점**: 초기 설정 복잡 (fly.toml, Dockerfile)

### 공통 필요 사항
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` 환경변수
- `RAILS_MASTER_KEY` (credentials.yml.enc)
- `DATABASE_URL` PostgreSQL 연결 문자열
- `APP_DOMAIN` 메인 도메인 설정 (서브도메인 생성에 사용)

---

## 9. Phase별 구현 핵심 포인트

### Phase 1 (기반 셋업)
- `rails new meeting-rails -d postgresql --css tailwind` 실행
- `config/application.rb`에 `config.action_dispatch.tld_length = 0` 추가 (로컬 서브도메인)
- `Current` 모델 생성 (`app/models/current.rb`)
- Devise 설치 시 User 모델에 `:confirmable` 고려

### Phase 2 (예약 핵심)
- Room CRUD는 admin 네임스페이스에서만 가능 (일반 사용자는 index만)
- Reservation의 `has_secure_password`는 `password_confirmation` 필드 UI 필요
- 층 목록은 `Room.where(organization: Current.organization).distinct.pluck(:floor)` 동적 생성

### Phase 3 (결제)
- Stripe 개발 환경: `stripe listen --forward-to localhost:3000/webhooks/stripe`
- Checkout 완료 후 redirect URL: `admin_subscription_url(subdomain: Current.organization.subdomain)`

### Phase 4 (완성도)
- rack-attack 기본 설정:
  ```ruby
  # config/initializers/rack_attack.rb
  Rack::Attack.throttle('reservations/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/reservations') && req.post?
  end
  ```

---

## 10. 빠른 참조 — 중요 파일 경로

| 파일 | 역할 |
|------|------|
| `app/models/current.rb` | CurrentAttributes (tenant context) |
| `app/controllers/application_controller.rb` | `set_current_tenant` 게이트 |
| `app/controllers/admin/base_controller.rb` | org_admin 권한 게이트 |
| `app/controllers/webhooks_controller.rb` | Stripe 이벤트 수신 |
| `config/routes.rb` | 서브도메인 constraints |
| `db/seeds.rb` | free/basic/pro 플랜 초기 데이터 |
| `config/initializers/rack_attack.rb` | 레이트리밋 규칙 |

---

*작성일: 2026-02-28 | 기반 문서: PLAN.md*
