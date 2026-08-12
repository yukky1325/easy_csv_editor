# frozen_string_literal: true

module PosthogTrackable
  extend ActiveSupport::Concern

  private

  def posthog_distinct_id
    session.id.to_s.presence || "anonymous"
  end

  def track_posthog(event, properties = {})
    Analytics::PosthogTracker.capture(
      distinct_id: posthog_distinct_id,
      event: event,
      properties: properties.merge(app_environment: Rails.env)
    )
  end
end
