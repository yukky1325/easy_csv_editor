# frozen_string_literal: true

module PosthogHelper
  def posthog_enabled?
    Analytics::PosthogTracker.enabled?
  end

  def posthog_distinct_id
    session.id.to_s.presence || "anonymous"
  end

  def posthog_api_host
    Rails.configuration.x.posthog.host
  end

  def posthog_api_key
    Rails.configuration.x.posthog.api_key
  end
end
