# frozen_string_literal: true

require "test_helper"

class Analytics::PosthogTrackerTest < ActiveSupport::TestCase
  test "disabled by default in test environment" do
    assert_not Analytics::PosthogTracker.enabled?
  end

  test "capture is no-op when disabled" do
    assert_nil Analytics::PosthogTracker.capture(
      distinct_id: "test-session",
      event: "csv_uploaded",
      properties: { row_count: 1 }
    )
  end

  test "capture delegates to PostHog when enabled" do
    require "posthog"

    with_posthog_enabled(true) do
      captured = nil
      original_capture = PostHog.method(:capture)
      PostHog.define_singleton_method(:capture) { |payload| captured = payload }

      begin
        Analytics::PosthogTracker.capture(
          distinct_id: "session-123",
          event: "csv_processed",
          properties: { rows_after: 10 }
        )
      ensure
        PostHog.define_singleton_method(:capture, original_capture)
      end

      assert_equal "session-123", captured[:distinct_id]
      assert_equal "csv_processed", captured[:event]
      assert_equal 10, captured[:properties]["rows_after"]
    end
  end

  private

  def with_posthog_enabled(enabled)
    original = Rails.configuration.x.posthog.enabled
    Rails.configuration.x.posthog.enabled = enabled
    yield
  ensure
    Rails.configuration.x.posthog.enabled = original
  end
end
