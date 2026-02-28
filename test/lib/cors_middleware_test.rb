require "test_helper"
require "rack/mock"

class CorsMiddlewareTest < ActiveSupport::TestCase
  test "adds cors headers for explicit allowed origin" do
    with_env("CORS_ALLOWED_ORIGINS" => "https://allowed.example.com", "APP_DOMAIN" => nil) do
      app = ->(_env) { [ 200, { "Content-Type" => "text/plain" }, [ "ok" ] ] }
      middleware = CorsMiddleware.new(app)

      env = Rack::MockRequest.env_for("/", "HTTP_ORIGIN" => "https://allowed.example.com")
      status, headers, _body = middleware.call(env)

      assert_equal 200, status
      assert_equal "https://allowed.example.com", headers["Access-Control-Allow-Origin"]
    end
  end

  test "allows app subdomain origin when app domain matches" do
    with_env("CORS_ALLOWED_ORIGINS" => nil, "APP_DOMAIN" => "myapp.com") do
      app = ->(_env) { [ 200, {}, [ "ok" ] ] }
      middleware = CorsMiddleware.new(app)

      env = Rack::MockRequest.env_for("/", "HTTP_ORIGIN" => "https://demo.myapp.com")
      _status, headers, _body = middleware.call(env)

      assert_equal "https://demo.myapp.com", headers["Access-Control-Allow-Origin"]
    end
  end

  test "handles preflight request for allowed origin" do
    with_env("CORS_ALLOWED_ORIGINS" => "https://allowed.example.com", "APP_DOMAIN" => nil) do
      app = ->(_env) { [ 404, {}, [] ] }
      middleware = CorsMiddleware.new(app)

      env = Rack::MockRequest.env_for(
        "/",
        "REQUEST_METHOD" => "OPTIONS",
        "HTTP_ORIGIN" => "https://allowed.example.com",
        "HTTP_ACCESS_CONTROL_REQUEST_HEADERS" => "Content-Type,Authorization"
      )
      status, headers, body = middleware.call(env)

      assert_equal 204, status
      assert_equal "Content-Type,Authorization", headers["Access-Control-Allow-Headers"]
      assert_equal [], body
    end
  end

  test "does not add headers for disallowed origin" do
    with_env("CORS_ALLOWED_ORIGINS" => "https://allowed.example.com", "APP_DOMAIN" => nil) do
      app = ->(_env) { [ 200, { "X-Test" => "ok" }, [ "ok" ] ] }
      middleware = CorsMiddleware.new(app)

      env = Rack::MockRequest.env_for("/", "HTTP_ORIGIN" => "https://blocked.example.com")
      _status, headers, _body = middleware.call(env)

      assert_nil headers["Access-Control-Allow-Origin"]
      assert_equal "ok", headers["X-Test"]
    end
  end

  private

  def with_env(values)
    backup = {}
    values.each do |key, value|
      backup[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    backup.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
