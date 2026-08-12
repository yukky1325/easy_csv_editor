# frozen_string_literal: true

module Analytics
  class PosthogTracker
    class << self
      def enabled?
        Rails.configuration.x.posthog.enabled
      end

      def capture(distinct_id:, event:, properties: {})
        return unless enabled?

        PostHog.capture(
          distinct_id: distinct_id,
          event: event,
          properties: sanitize_properties(properties)
        )
      rescue StandardError => e
        Rails.logger.warn("[PostHog] capture failed: #{e.class}: #{e.message}")
        nil
      end

      private

      def sanitize_properties(properties)
        properties.transform_keys(&:to_s).compact
      end
    end
  end
end
