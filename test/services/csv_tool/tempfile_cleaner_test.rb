# frozen_string_literal: true

require "test_helper"

class CsvTool::TempfileCleanerTest < ActiveSupport::TestCase
  setup do
    @base_dir = Rails.root.join("tmp", "csv_tool_cleaner_test_#{Process.pid}")
    FileUtils.mkdir_p(@base_dir)
    @now = Time.zone.parse("2026-08-05 12:00:00")
    @cleaner = CsvTool::TempfileCleaner.new(
      base_dir: @base_dir,
      ttl: 24.hours,
      now: @now
    )
  end

  teardown do
    FileUtils.rm_rf(@base_dir)
  end

  test "deletes files older than ttl" do
    old_file = @base_dir.join("old.csv")
    old_file.write("old")
    old_time = (@now - 25.hours).to_time
    File.utime(old_time, old_time, old_file)

    new_file = @base_dir.join("new.csv")
    new_file.write("new")

    assert_equal 1, @cleaner.cleanup!
    assert_not old_file.exist?
    assert_predicate new_file, :exist?
  end

  test "returns zero when directory is empty" do
    assert_equal 0, @cleaner.cleanup!
  end

  test "returns zero when directory does not exist" do
    cleaner = CsvTool::TempfileCleaner.new(
      base_dir: @base_dir.join("missing"),
      ttl: 24.hours,
      now: @now
    )

    assert_equal 0, cleaner.cleanup!
  end
end
