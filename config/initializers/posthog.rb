# frozen_string_literal: true

Rails.application.configure do
  api_key = ENV["POSTHOG_API_KEY"].presence

  config.x.posthog.api_key = api_key
  config.x.posthog.host = ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com")
  config.x.posthog.enabled = (
    if ENV.key?("POSTHOG_ENABLED")
      ActiveModel::Type::Boolean.new.cast(ENV["POSTHOG_ENABLED"])
    else
      Rails.env.production?
    end
  ) && api_key.present?
end

if Rails.configuration.x.posthog.enabled
  require "posthog/rails"

  PostHog.init do |config|
    config.api_key = Rails.configuration.x.posthog.api_key
    config.host = Rails.configuration.x.posthog.host
    config.on_error = proc { |status, message| Rails.logger.warn("[PostHog] #{status}: #{message}") }
  end

  PostHog::Rails.configure do |config|
    config.auto_capture_exceptions = false
    config.use_tracing_headers = true
  end
end
