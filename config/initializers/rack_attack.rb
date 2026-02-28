class Rack::Attack
  # 예약 생성: IP당 분당 10회
  throttle("reservations/create/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/reservations") && req.post?
  end

  # 로그인 시도: IP당 5분에 5회
  throttle("login/ip", limit: 5, period: 5.minutes) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # 로그인 시도: 이메일당 5분에 5회
  throttle("login/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email")&.downcase&.strip
    end
  end

  # 429 응답 포맷
  self.throttled_responder = lambda do |env|
    req = Rack::Request.new(env)
    if req.accepts?("application/json")
      [ 429, { "Content-Type" => "application/json" },
        [ { error: "요청이 너무 많습니다. 잠시 후 다시 시도하세요." }.to_json ] ]
    else
      [ 429, { "Content-Type" => "text/html" },
        [ "<h1>요청이 너무 많습니다.</h1><p>잠시 후 다시 시도하세요.</p>" ] ]
    end
  end
end
