# frozen_string_literal: true

namespace :csv_tool do
  desc "Delete temporary CSV files older than the configured TTL (24 hours)"
  task cleanup: :environment do
    deleted = CsvTool::TempfileCleaner.new.cleanup!
    puts "Deleted #{deleted} file(s) from #{CsvTool::TEMP_DIR}"
  end
end
