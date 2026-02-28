# 회의실 예약 시스템 — Rails 멀티테넌트 SaaS 설계 계획

## Context

병원 J동 회의실 예약 앱을 Ruby on Rails 기반 멀티테넌트 SaaS로 새로 구축한다.
여러 병원/회사(Tenant)가 각자 계정으로 가입 후 독립적으로 회의실을 관리·예약하며,
월 구독(Stripe) 결제로 서비스를 이용한다. 회의실은 관리자 패널에서 동적으로 추가/수정/삭제한다.

---

## 기술 스택

| 항목 | 선택 |
|------|------|
| Framework | Rails 8 + Hotwire (Turbo + Stimulus) |
| DB | PostgreSQL |
| CSS | Tailwind CSS (tailwindcss-rails gem) |
| 인증 | Devise |
| 결제 | Stripe (stripe-ruby gem) |
| 레이트리밋 | rack-attack |
| 배포 목표 | Render.com or Fly.io |

---

## 멀티테넌시 전략

- **서브도메인 기반**: `hospital-a.myapp.com` → Organization A
- **Row-level isolation**: 모든 데이터 모델에 `organization_id` FK
- `ApplicationController#set_current_tenant` 로 요청별 Organization 해석
- 슈퍼어드민은 별도 네임스페이스(`/super_admin`)

---

## 디렉토리 구조

```
meeting-rails/
  app/
    models/
      organization.rb       ← tenant (subdomain, plan, stripe_customer_id)
      user.rb               ← Devise, role: org_admin / member
      room.rb               ← floor, name, capacity, active (org scoped)
      reservation.rb        ← has_secure_password, time conflict validation
      plan.rb               ← free/basic/pro (room_limit, monthly_price)
      subscription.rb       ← stripe_subscription_id, status, period_end
    controllers/
      application_controller.rb   ← tenant 해석, 인증 게이트
      reservations_controller.rb  ← 예약 CRUD (비밀번호 인증 포함)
      rooms_controller.rb         ← 층별 회의실 목록
      admin/
        base_controller.rb        ← org_admin 권한 게이트
        rooms_controller.rb       ← 회의실 CRUD
        reservations_controller.rb ← 전체 예약 조회/관리
        dashboard_controller.rb   ← 사용 통계
        subscriptions_controller.rb ← 플랜 변경, 결제 관리
      super_admin/
        organizations_controller.rb ← 전체 테넌트 관리
        plans_controller.rb
      webhooks_controller.rb      ← Stripe webhook 처리
      registrations_controller.rb ← 조직 신규 가입
    views/
      layouts/
        application.html.erb
        admin.html.erb
      reservations/           ← index(층/날짜 선택), new, show, verify
      rooms/                  ← index (공개용 회의실 목록)
      admin/rooms/            ← 회의실 CRUD 폼
      admin/dashboard/        ← 예약 통계
      admin/subscriptions/    ← 플랜 선택, 결제 페이지
      super_admin/            ← 슈퍼어드민 UI
      landing/index.html.erb  ← 마케팅/소개 페이지
      registrations/new.html.erb ← 조직 가입 폼
    javascript/
      controllers/
        reservation_form_controller.js  ← Stimulus: 시간 슬롯 선택
        password_modal_controller.js    ← Stimulus: 비밀번호 확인 모달
        clock_controller.js             ← Stimulus: 실시간 시계
  config/
    routes.rb               ← 서브도메인 constraints + 네임스페이스
  db/
    migrate/
      001_create_organizations.rb
      002_create_plans.rb
      003_create_subscriptions.rb
      004_create_users.rb
      005_create_rooms.rb
      006_create_reservations.rb
    seeds.rb                ← 기본 플랜 데이터
```

---

## 핵심 모델 설계

### Organization (tenant)
```ruby
# subdomain :string (unique, URL-safe)
# name :string
# plan_id :bigint
# stripe_customer_id :string
# active :boolean default true
has_many :users
has_many :rooms
has_many :reservations, through: :rooms
has_one :subscription
```

### Room
```ruby
# organization_id :bigint
# floor :string  (관리자가 자유 입력 — 하드코딩 없음)
# name :string
# capacity :integer
# active :boolean default true
belongs_to :organization
has_many :reservations
scope :active, -> { where(active: true) }
```

### Reservation
```ruby
# room_id :bigint
# organization_id :bigint  (빠른 조회용 비정규화)
# date :date
# start_time :time
# end_time :time
# organizer :string
# purpose :string
# password_digest :string  (has_secure_password)
validates :date, comparison: { greater_than_or_equal_to: -> { Date.current } }
validate :no_time_overlap
```

### Plan
```ruby
# name :string ('free','basic','pro')
# price_cents :integer (월 구독료, 센트 단위)
# room_limit :integer (nil = 무제한)
# stripe_price_id :string
```

### Subscription
```ruby
# organization_id :bigint
# plan_id :bigint
# stripe_subscription_id :string
# status :string ('active','past_due','canceled')
# current_period_end :datetime
```

---

## 라우팅 설계

```ruby
# 메인 도메인: www.myapp.com
root 'landing#index'
resources :registrations, only: [:new, :create]  # 조직 가입

# 서브도메인: *.myapp.com
constraints(subdomain: /.+/) do
  scope module: 'tenant' do
    root 'reservations#index'          # 층/날짜 선택
    resources :rooms, only: [:index]
    resources :reservations do
      member do
        get  :verify                   # 비밀번호 확인 폼
        post :authenticate             # 비밀번호 검증
      end
    end
    namespace :admin do
      root 'dashboard#index'
      resources :rooms
      resources :reservations, only: [:index, :destroy]
      resource :subscription
    end
  end
end

namespace :super_admin do
  resources :organizations
  resources :plans
end

post '/webhooks/stripe', to: 'webhooks#stripe'
```

---

## 구현 순서 (단계별)

### Phase 1 — 기반 셋업 ✅ 완료 (2026-02-28)
1. ✅ `rails new meeting-rails -d postgresql --css tailwind` + Tailwind 설정
2. ✅ Devise 설치 + User/Organization 모델 생성 + role enum (member/org_admin)
3. ✅ 서브도메인 라우팅 + `set_current_tenant` (before_action) + Current attributes
4. ✅ 기본 플랜 seed 데이터 (free/basic/pro) + 데모 조직/관리자/회의실

**Phase 1 추가 구현**:
- ✅ 마이그레이션: organizations, users, plans, subscriptions, rooms, reservations
- ✅ 모델: Current, Plan, Subscription, Room, Reservation (has_secure_password)
- ✅ 컨트롤러: LandingController, RegistrationsController, ApplicationController (set_current_tenant)
- ✅ 기본 뷰: 랜딩, 가입 폼, Tailwind 스타일 적용
- ✅ DB: PostgreSQL 마이그레이션 + seed 검증 완료

### Phase 2 — 예약 핵심 기능 ✅ 완료 (2026-02-28)
5. ✅ Room 모델 + Admin CRUD (rooms_controller, form partial)
6. ✅ Reservation 모델 (has_secure_password, 시간 중복 검증 with .lock, organization_id 비정규화)
7. ✅ 예약 생성/수정/삭제 플로우 (비밀번호 인증 via verify/authenticate)
8. ✅ 층별 타임라인 뷰 (index + _timeline partial, 시간대별 슬롯)

**Phase 2 추가 구현**:
- ✅ Devise 뷰 생성 및 Tailwind 커스터마이징 (로그인 페이지 한국어)
- ✅ Admin 누락 뷰: reservations/index (날짜별 조회), subscriptions/show (플랜 선택)
- ✅ Admin 컨트롤러: rooms, reservations, subscriptions, dashboard
- ✅ Stimulus 3종 컨트롤러:
  - `clock_controller.js`: 실시간 시계 표시
  - `password_modal_controller.js`: 비밀번호 확인 모달
  - `reservation_form_controller.js`: 시간 유효성 검사, 종료시간 자동 설정, 제출 버튼 제어
- ✅ 보안:
  - `rack_attack.rb`: 로그인 5회/5분, 예약생성 10회/1분 레이트리밋
  - `application.rb`: 보안 헤더 추가 (X-Frame-Options, X-Content-Type-Options 등)
- ✅ 환경변수: `dotenv-rails` gem + `.env` 파일 (DB_PASSWORD 등)
- ✅ Stripe 초기화: `config/initializers/stripe.rb`
- ✅ 라우팅: 서브도메인 constraints, admin namespace, webhook POST

**Phase 2 검증 완료**:
- ✅ 예약 CRUD: 생성/인증/수정/삭제 정상 동작
- ✅ 시간 중복 검증: .lock으로 race condition 방지
- ✅ has_secure_password: BCrypt 해싱 + 인증 정상
- ✅ 타임라인: 층별/날짜별 조회 + 슬롯 UI 정상
- ✅ HTTP 상태: 200 (공개), 302 (관리자 미인증) 정상

### Phase 3 — 구독/결제 ✅ 완료 (2026-02-28)
9. ✅ Stripe 연동 (checkout session, webhook 처리)
10. ✅ 플랜별 회의실 수 제한 enforcing (create 시 검사)
11. ✅ 관리자 구독 관리 페이지 (플랜 변경, 결제 이력)
12. ✅ Stripe 테스트 결제 검증 (2026-02-28)

**Phase 3 추가 구현 (2026-02-28)**:
- ✅ `Admin::SubscriptionsController`:
  - 유료 플랜 `stripe_price_id` 누락 방어
  - Stripe 결제 세션/구독 취소 예외 처리
  - 결제 이력(Invoice 10건) 조회 로직 추가
- ✅ `WebhooksController`:
  - `checkout.session.completed` 처리 idempotent 갱신 방식으로 보강
  - `customer.subscription.updated` 시 Stripe price 기반 Plan 동기화
  - Stripe 상태값 정규화(`active/past_due/canceled`) 및 타임스탬프 변환 유틸 추가
- ✅ `admin/subscriptions/show`:
  - 결제 이력 테이블(일자/금액/상태/영수증 링크) UI 추가
- ✅ DB 무결성 강화:
  - `subscriptions.organization_id` unique index 추가
  - `subscriptions.stripe_subscription_id` partial unique index 추가
  - 로컬 마이그레이션 실행 (`bin/rails db:migrate`)
- ✅ Seed 보강:
  - `basic/pro` 플랜의 `stripe_price_id` 환경변수 기반 세팅(`STRIPE_PRICE_BASIC`, `STRIPE_PRICE_PRO`)
- ✅ 테스트 보강:
  - `test/controllers/webhooks_controller_test.rb` 추가
  - 검증 시나리오: `checkout.session.completed`, `customer.subscription.updated`, 잘못된 서명 400 응답, 비브라우저(User-Agent 없음) webhook 수신
- ✅ 결제 동기화 안정성 보강:
  - `StripeSubscriptionSync` 서비스 추가로 웹훅/관리자 화면 동기화 로직 공통화
  - 결제 성공 리다이렉트(`session_id`) 시 서버측 재확인(reconciliation) 구현
  - webhook 지연/미수신 시에도 관리자 화면 진입으로 구독 상태 복구 가능
- ✅ 테스트 추가:
  - `test/controllers/admin/subscriptions_controller_test.rb`
  - 검증 시나리오: `session_id` 기반 구독 동기화
- ✅ Stripe 실검증 사전점검 자동화:
  - `lib/tasks/stripe_preflight.rake` 추가 (`bin/rails stripe:preflight`)
  - 점검 항목: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, 유료 플랜 `stripe_price_id`, Stripe CLI 설치 여부
  - Windows 환경에서 Stripe CLI 설치는 되었지만 PATH 미반영인 상태를 경고로 분리 감지
  - `.env` 직접 파싱 fallback 추가 (dotenv 로딩 상태와 무관하게 키/placeholder 점검 가능)
- 🔄 실검증 블로커 현황 (2026-02-28):
  - ✅ Stripe CLI 설치 완료 (`winget install --id Stripe.StripeCli`)
  - ⚠️ 현재 셸 PATH 미반영으로 `stripe` 명령 인식 실패 가능 (새 터미널 필요)
  - ✅ `.env` 실키 반영 완료 (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`)
  - ✅ Stripe `basic/pro` 테스트 Price 생성 및 `.env` 연동 (`STRIPE_PRICE_BASIC`, `STRIPE_PRICE_PRO`)
  - ✅ Stripe Checkout Session 생성 성공 (`mode=subscription`, success/cancel URL 정상 설정)
  - ✅ Stripe listener + webhook 실제 수신 확인 (`checkout.session.completed` → `POST /webhooks/stripe` 200)
  - ✅ `/up` 헬스체크 200, 서버 실행/연결 문제 해결 후 재검증 완료

**Phase 3 실검증 중 보완 (2026-02-28)**:
- ✅ 마이그레이션 안전화:
  - `20260228120000_add_subscription_uniqueness_indexes`를 idempotent하게 수정 (기존 인덱스 충돌 처리)
- ✅ webhook 안정성 보강:
  - `STRIPE_WEBHOOK_SECRET` 누락 시 `.env` fallback 로직 추가
  - `StripeSubscriptionSync` 상수 참조를 절대 경로(`::StripeSubscriptionSync`)로 수정
- ✅ 운영 이슈 해결:
  - stale PID(`tmp/pids/server.pid`)로 인한 서버 기동 실패 해결
  - Stripe listener forwarding 주소를 `127.0.0.1`로 고정해 `localhost(::1)` 연결 거부 이슈 해결
- ℹ️ 참고:
  - Stripe CLI `trigger checkout.session.completed` fixture는 기본 `mode=payment` payload를 보내므로,
    실제 subscription 객체 동기화는 자동화 테스트(`webhooks_controller_test`, `admin/subscriptions_controller_test`)로 보완 검증

### Phase 4 — 완성도 ✅ 완료 (2026-02-28)
13. ✅ 랜딩 페이지 (소개 + 가입 유도)
14. ✅ 조직 가입 wizard (subdomain 가용성 검사)
15. ✅ 슈퍼어드민 패널 (조직 관리, 플랜 CRUD)
16. ✅ 보안 강화: HTTPS 강제, CSP 헤더, CORS
17. ✅ 배포 준비 (Render/Fly.io 설정)

**Phase 4 추가 구현 (2026-02-28)**:
- ✅ 가입 Wizard 보강:
  - `RegistrationsController#subdomain_availability` JSON 엔드포인트 추가
  - `Organization` 서브도메인 정규화/길이 검증(3~63) 및 가용성 헬퍼 추가
  - `subdomain_check_controller.js`로 입력 중 실시간 가용성 확인 + 제출 버튼 제어
- ✅ 슈퍼어드민 패널 구현:
  - `SuperAdmin::BaseController` + HTTP Basic 인증(운영은 ENV, 개발/테스트 fallback)
  - `SuperAdmin::OrganizationsController`, `SuperAdmin::PlansController` CRUD 추가
  - 슈퍼어드민 전용 레이아웃/뷰 추가 및 `/super_admin` 루트 연결
- ✅ 보안 강화(부분 완료):
  - `production.rb`에서 `config.force_ssl`, `config.assume_ssl`, host authorization 설정
  - `content_security_policy.rb` 활성화 및 nonce 자동 부여 설정
- ✅ 보안 강화(추가 완료):
  - `lib/cors_middleware.rb` 추가 (화이트리스트 기반 CORS + preflight OPTIONS 처리)
  - `config/application.rb`에서 `CORS_ENABLED` 기반 미들웨어 활성화
  - `APP_DOMAIN` 서브도메인 및 `CORS_ALLOWED_ORIGINS` 명시 도메인 허용
- ✅ 배포 준비(추가 완료):
  - `render.yaml` 추가 (web + postgres + 필수 env 템플릿)
  - `fly.toml.example` 추가 (헬스체크/HTTPS/기본 env)
  - `.env.example` 추가 및 `README.md` 전면 정리
- ✅ 품질 안정화(추가 완료):
  - Ruby/Rails 테스트 환경에서 `Module#stub` 비지원 이슈 대응을 위해 `test/test_helper.rb`에 `stub_class_method` 헬퍼 추가
  - `webhooks_controller_test`, `admin/subscriptions_controller_test`를 호환 스텁 방식으로 수정
  - `admin/subscriptions/show`의 가격 포맷 버그(`to_s(:delimited)`)를 `number_with_delimiter`로 수정
  - 검증: `ruby bin/rails test` 전체 통과 (5 runs, 0 failures)
- ✅ 검증 범위 심화(추가 완료):
  - `test/controllers/registrations_controller_test.rb` 추가:
    - 서브도메인 가용성 API의 기존값 충돌/정규화/포맷 검증 시나리오 고정
  - `test/controllers/super_admin/organizations_controller_test.rb` 추가:
    - HTTP Basic 인증 강제 + 조직 생성 플로우 검증
  - `test/controllers/super_admin/plans_controller_test.rb` 추가:
    - 플랜 생성 및 사용 중 플랜 삭제 방지 검증
  - `test/lib/cors_middleware_test.rb` 추가:
    - 명시 화이트리스트/APP_DOMAIN 서브도메인/preflight/disallow 시나리오 검증
  - 검증: `ruby bin/rails test` 전체 통과 (17 runs, 0 failures)
- ✅ 운영 이슈 보완(추가 완료):
  - 가입 직후 메인 도메인 → 테넌트 서브도메인 이동 시
    `ActionController::Redirecting::OpenRedirectError` 발생 이슈 해결
  - `RegistrationsController#create` 리다이렉트에
    `allow_other_host: true` 반영으로 의도된 cross-host 이동을 명시 허용
  - 개발환경 CSP 보완:
    - `connect-src`에 개발/테스트 한정 `http` 허용 추가
    - Turbo 기반 `localhost -> *.localhost` 이동 시 `Failed to fetch`/CSP 차단 이슈 해결
  - 관리자 진입 라우팅 보완:
    - 메인 도메인에서 상단 `관리자` 링크 클릭 시 `/admin` 404 발생 이슈 수정
    - `application` 레이아웃의 관리자 링크를 로그인 사용자의 조직 서브도메인 URL로 고정
  - Render 배포 실패 대응:
    - `config/database.yml` production 연결을 `DATABASE_URL` 우선 사용으로 변경
    - `cache/queue/cable` DB도 `*_DATABASE_URL` 또는 `DATABASE_URL` fallback 사용
    - `render.yaml`에서 DB 자동 연결 의존 제거 및 `DATABASE_URL` 수동 주입 방식으로 정리
  - Render 접속 403 대응:
    - `production.rb` Host Authorization에 `RENDER_EXTERNAL_HOSTNAME` 자동 허용 추가
    - Render 기본 도메인(`*.onrender.com`) 접속 시 403 차단 이슈 해소

---

## 검증 방법

### 로컬 서버 실행
```bash
cd meeting-rails
DB_PASSWORD="dkrehafkr1!" rails server
# 또는 .env 파일 사용 (dotenv-rails가 자동 로드)
```

### Phase 1+2 완료 상태 검증
1. **랜딩 페이지**: `http://localhost:3000` → 200 OK
2. **예약 앱**: `http://demo.localhost:3000` → 200 OK (테넌트 컨텍스트)
3. **예약 타임라인**: `/reservations` → 층/날짜 선택 → 슬롯 표시
4. **관리자**: `/admin` → 302 리다이렉트 (로그인 필요)
5. **로그인**: `/users/sign_in` → admin@demo.com / password123
6. **예약 CRUD**:
   - 생성: `/reservations/new` → 폼 제출 → 비밀번호 입력
   - 조회: `/reservations/:id` → 상세 정보 표시
   - 수정: "수정하기" → `/verify` (비밀번호 확인) → `/edit`
   - 삭제: "삭제하기" → `/verify` → 비밀번호 인증 후 삭제
7. **관리자 기능**:
   - 회의실: `/admin/rooms` → CRUD 가능
   - 예약: `/admin/reservations` → 날짜별 조회 + 삭제
   - 대시보드: `/admin` → 통계 표시
   - 구독: `/admin/subscription` → 플랜 선택 UI (Phase 3에서 결제)
8. **보안 검증**:
   - 레이트리밋: 로그인 5회 초과 → 429 응답
   - 시간 중복: 동일 방/시간 예약 → 오류 메시지
   - 테넌트 격리: `demo` 관리자가 다른 조직 데이터 접근 불가

### Phase 3 준비 (Stripe 테스트)
```bash
# 1. Stripe 테스트 키 설정 (STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET .env에)
# 2. Webhook 로컬 테스트
stripe listen --forward-to localhost:3000/webhooks/stripe
# 3. 결제 플로우 검증 (Phase 3에서)
# 4. 자동화 테스트 실행
bin/rails test test/controllers/webhooks_controller_test.rb
bin/rails test test/controllers/admin/subscriptions_controller_test.rb
# 5. 실검증 사전점검
bin/rails stripe:preflight
```

### 작업 기록 원칙
- 진행 중인 구현은 완료 즉시 `PLAN.md`에 체크/추가 기록한다.
- 다음 세션에서도 동일하게 `PLAN.md`를 기준으로 상태를 누적 관리한다.

### Phase 3 블로커 해소 가이드 (Windows)
```powershell
# 1) Stripe CLI 설치
winget install Stripe.StripeCLI
# 설치 직후 새 터미널을 열어 PATH 반영

# 2) Stripe 로그인
stripe login

# 3) .env 실키 설정 (예시값 제거)
# STRIPE_SECRET_KEY=sk_test_...
# STRIPE_WEBHOOK_SECRET=whsec_...   (listen 실행 후 발급값으로 교체)

# 4) 사전점검
bin/rails stripe:preflight

# 5) webhook 포워딩
stripe listen --forward-to localhost:3000/webhooks/stripe
```

---

## Ruby/Rails 설치 (선행 조건)

```powershell
# 1. rubyinstaller.org 에서 Ruby+Devkit 3.3.x (x64) 설치
# 2. 설치 후 ridk install → 1, 3 선택
# 3. postgresql.org 에서 PostgreSQL 설치
# 4. 새 PowerShell 열고:
gem install rails
gem install bundler
```
