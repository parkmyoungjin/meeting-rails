require "uri"

class CorsMiddleware
  DEFAULT_METHODS = "GET, POST, PUT, PATCH, DELETE, OPTIONS".freeze
  DEFAULT_HEADERS = "Origin, Content-Type, Accept, Authorization, X-Requested-With".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    origin = env["HTTP_ORIGIN"].to_s
    return @app.call(env) if origin.empty?

    return @app.call(env) unless allowed_origin?(origin)

    if env["REQUEST_METHOD"] == "OPTIONS"
      return [ 204, cors_headers(origin, env), [] ]
    end

    status, headers, body = @app.call(env)
    [ status, headers.merge(cors_headers(origin, env)), body ]
  end

  private

  def allowed_origin?(origin)
    explicit_allowed_origins.include?(origin) || allowed_app_domain?(origin)
  end

  def explicit_allowed_origins
    @explicit_allowed_origins ||= ENV.fetch("CORS_ALLOWED_ORIGINS", "")
      .split(",")
      .map { |value| value.strip }
      .reject(&:empty?)
  end

  def allowed_app_domain?(origin)
    app_domain = ENV["APP_DOMAIN"].to_s.strip
    return false if app_domain.empty?

    uri = URI.parse(origin)
    return false if uri.host.blank?

    host = uri.host.downcase
    host == app_domain || host.end_with?(".#{app_domain}")
  rescue URI::InvalidURIError
    false
  end

  def cors_headers(origin, env)
    requested_headers = env["HTTP_ACCESS_CONTROL_REQUEST_HEADERS"].to_s
    allowed_headers = requested_headers.present? ? requested_headers : DEFAULT_HEADERS

    {
      "Access-Control-Allow-Origin" => origin,
      "Access-Control-Allow-Methods" => DEFAULT_METHODS,
      "Access-Control-Allow-Headers" => allowed_headers,
      "Access-Control-Max-Age" => "600",
      "Vary" => "Origin"
    }
  end
end
