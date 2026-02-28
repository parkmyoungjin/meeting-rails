Rails.application.routes.draw do
  # 헬스체크
  get "up" => "rails/health#show", as: :rails_health_check

  # 메인 도메인: www.myapp.com / localhost:3000
  root "landing#index"
  resources :registrations, only: [ :new, :create ] do
    collection do
      get :subdomain_availability
    end
  end
  devise_for :users

  # 서브도메인: demo.localhost:3000
  constraints(subdomain: /.+/) do
    root "reservations#index", as: :tenant_root
    resources :rooms, only: [ :index ]
    resources :reservations do
      member do
        get  :verify
        post :authenticate
      end
    end
    namespace :admin do
      root "dashboard#index"
      resources :rooms
      resources :reservations, only: [ :index, :destroy ]
      resource  :subscription
    end
  end

  # 슈퍼어드민 (서브도메인 없음)
  namespace :super_admin do
    root "organizations#index"
    resources :organizations
    resources :plans
  end

  # Stripe webhook
  post "/webhooks/stripe", to: "webhooks#stripe"
end
