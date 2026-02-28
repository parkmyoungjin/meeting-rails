require_relative "boot"

require "rails/all"
require_relative "../lib/cors_middleware"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MeetingRails
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Seoul"
    # config.eager_load_paths << Rails.root.join("extras")

    # 로컬 서브도메인 인식 (demo.localhost:3000)
    config.action_dispatch.tld_length = 0

    # rack-attack 미들웨어 등록
    config.middleware.use Rack::Attack

    # CORS: 기본은 production에서만 활성화, 필요한 경우 CORS_ENABLED=true로 명시
    cors_enabled = ENV.fetch("CORS_ENABLED", Rails.env.production?.to_s) == "true"
    config.middleware.insert_before 0, CorsMiddleware if cors_enabled

    # 보안 헤더
    config.action_dispatch.default_headers = {
      "X-Frame-Options"        => "SAMEORIGIN",
      "X-Content-Type-Options" => "nosniff",
      "X-XSS-Protection"       => "1; mode=block",
      "Referrer-Policy"        => "strict-origin-when-cross-origin"
    }
  end
end
