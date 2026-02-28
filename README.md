# meeting-rails

Rails 8 + Hotwire 기반 멀티테넌트 회의실 예약 SaaS입니다.  
서브도메인 단위 테넌트 분리, Stripe 구독 결제, 관리자/슈퍼어드민 패널을 포함합니다.

## Requirements

- Ruby `3.4.x`
- PostgreSQL
- Node 설치 없이 동작 (importmap + tailwindcss-rails)

## Local Setup

1. 의존성 설치
```bash
bundle install
```

2. 환경변수 준비
```bash
cp .env.example .env
```

3. DB 준비
```bash
bin/rails db:prepare
bin/rails db:seed
```

4. 실행
```bash
bin/rails server
```

## Key URLs

- 랜딩: `http://localhost:3000`
- 테넌트 데모: `http://demo.localhost:3000`
- 관리자: `http://demo.localhost:3000/admin`
- 슈퍼어드민: `http://localhost:3000/super_admin`

슈퍼어드민은 HTTP Basic 인증을 사용하며, 운영에서는 아래 ENV가 필수입니다.
- `SUPER_ADMIN_USERNAME`
- `SUPER_ADMIN_PASSWORD`

## Stripe

```bash
bin/rails stripe:preflight
```

Webhook 로컬 포워딩:
```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

## Security Notes

- Production HTTPS 강제: `FORCE_SSL=true`
- CSP 활성화: `config/initializers/content_security_policy.rb`
- CORS 화이트리스트: `CORS_ALLOWED_ORIGINS` + `APP_DOMAIN` 기반 서브도메인 허용

## Deployment

### Render

- `render.yaml` 포함
- 필수 시크릿: `RAILS_MASTER_KEY`, Stripe 키들, 슈퍼어드민 계정
- 헬스체크: `/up`

### Fly.io

- `fly.toml.example` 제공
- 복사 후 `fly.toml`로 사용
- 민감정보는 `fly secrets set`으로 설정

## Tests

```bash
bin/rails db:prepare RAILS_ENV=test
bin/rails test
```
