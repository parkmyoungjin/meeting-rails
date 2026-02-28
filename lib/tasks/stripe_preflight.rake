namespace :stripe do
  desc "Check Stripe prerequisites before running real checkout/webhook verification"
  task preflight: :environment do
    issues = []
    warnings = []
    dotenv_values = {}
    if File.exist?(Rails.root.join(".env"))
      File.foreach(Rails.root.join(".env")) do |line|
        next if line.strip.empty? || line.strip.start_with?("#")
        key, value = line.split("=", 2)
        next unless key && value
        dotenv_values[key.strip] = value.strip
      end
    end

    secret_key = ENV["STRIPE_SECRET_KEY"].to_s.strip
    secret_key = dotenv_values["STRIPE_SECRET_KEY"].to_s.strip if secret_key.empty?
    webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].to_s.strip
    webhook_secret = dotenv_values["STRIPE_WEBHOOK_SECRET"].to_s.strip if webhook_secret.empty?

    if secret_key.empty?
      issues << "STRIPE_SECRET_KEY is missing"
    elsif secret_key.include?("your_key_here")
      issues << "STRIPE_SECRET_KEY is still a placeholder value"
    end

    if webhook_secret.empty?
      issues << "STRIPE_WEBHOOK_SECRET is missing"
    elsif webhook_secret.include?("your_secret_here")
      issues << "STRIPE_WEBHOOK_SECRET is still a placeholder value"
    end

    paid_plans = Plan.where.not(price_cents: 0)
    missing_price_ids = paid_plans.where(stripe_price_id: [nil, ""])
    if missing_price_ids.exists?
      issues << "Paid plans missing stripe_price_id: #{missing_price_ids.pluck(:name).join(', ')}"
    end

    placeholder_price_ids = paid_plans.select { |plan| plan.stripe_price_id.to_s.end_with?("_test") }
    if placeholder_price_ids.any?
      warnings << "Paid plans appear to use test/placeholder price IDs: #{placeholder_price_ids.map(&:name).join(', ')}"
    end

    cli_available = false
    if Gem.win_platform?
      cli_available = system("where stripe >NUL 2>&1")
      unless cli_available
        installed_path = Dir.glob(
          File.join(ENV.fetch("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages", "Stripe.StripeCli*", "stripe.exe")
        ).first
        if installed_path
          cli_available = true
          warnings << "Stripe CLI is installed but not available in current PATH. Open a new terminal."
        end
      end
    else
      cli_available = system("command -v stripe >/dev/null 2>&1")
    end
    issues << "Stripe CLI is not installed or not in PATH" unless cli_available

    puts "== Stripe Preflight =="
    puts "Loaded from .env: #{dotenv_values.any? ? 'yes' : 'no'}"
    puts "Issues: #{issues.count}"
    issues.each { |item| puts "  - #{item}" }
    puts "Warnings: #{warnings.count}"
    warnings.each { |item| puts "  - #{item}" }

    abort("Preflight failed. Fix issues before running real Stripe verification.") if issues.any?

    puts "Preflight passed."
  end
end
