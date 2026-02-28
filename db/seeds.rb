# Plans
free_plan  = Plan.find_or_create_by!(name: "free") do |p|
  p.price_cents = 0
  p.room_limit  = 2
end

Plan.find_or_create_by!(name: "basic") do |p|
  p.price_cents = 29_000
  p.room_limit  = 10
  p.stripe_price_id = ENV.fetch("STRIPE_PRICE_BASIC", "price_basic_test")
end

Plan.find_or_create_by!(name: "pro") do |p|
  p.price_cents = 99_000
  p.room_limit  = nil
  p.stripe_price_id = ENV.fetch("STRIPE_PRICE_PRO", "price_pro_test")
end

Plan.find_by!(name: "basic").update!(stripe_price_id: ENV.fetch("STRIPE_PRICE_BASIC", "price_basic_test"))
Plan.find_by!(name: "pro").update!(stripe_price_id: ENV.fetch("STRIPE_PRICE_PRO", "price_pro_test"))

puts "플랜 생성: #{Plan.count}개"

# Demo Organization
demo = Organization.find_or_create_by!(subdomain: "demo") do |o|
  o.name   = "데모 병원"
  o.plan   = free_plan
  o.active = true
end
demo.update!(plan: free_plan) if demo.plan.nil?

# Demo Admin User
admin_user = User.find_or_create_by!(email: "admin@demo.com") do |u|
  u.password              = "password123"
  u.password_confirmation = "password123"
  u.role                  = :org_admin
  u.organization          = demo
end

# Demo Subscription
if demo.subscription.nil?
  demo.create_subscription!(
    plan:               free_plan,
    status:             "active",
    current_period_end: 100.years.from_now
  )
end

# Demo Rooms
[
  { floor: "1층", name: "소회의실 A", capacity: 6 },
  { floor: "1층", name: "소회의실 B", capacity: 8 },
].each do |attrs|
  Room.find_or_create_by!(organization: demo, name: attrs[:name]) do |r|
    r.floor    = attrs[:floor]
    r.capacity = attrs[:capacity]
  end
end

puts "데모 조직: #{demo.subdomain} (#{demo.name})"
puts "관리자: #{admin_user.email} / password123"
puts "회의실: #{demo.rooms.count}개"
puts ""
puts "접속: http://demo.localhost:3000"
puts "관리자: http://demo.localhost:3000/admin"
