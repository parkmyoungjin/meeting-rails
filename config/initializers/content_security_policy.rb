# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.base_uri    :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    if Rails.env.development? || Rails.env.test?
      # In local multi-tenant flow, Turbo fetch may cross origin (localhost -> *.localhost).
      policy.connect_src :self, :https, :http
    else
      policy.connect_src :self, :https
    end
    policy.frame_ancestors :none
    policy.form_action :self, :https
    policy.upgrade_insecure_requests true if Rails.env.production?
  end

  # Nonce is needed for importmap/Turbo script tags in stricter CSP mode.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)
  config.content_security_policy_nonce_auto = true
end
