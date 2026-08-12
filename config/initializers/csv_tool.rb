# frozen_string_literal: true

module CsvTool
  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_EXTENSION = ".csv"
  PREVIEW_ROW_LIMIT = 10
  TEMP_DIR = Rails.root.join("tmp", "csv_tool")
  TEMP_FILE_TTL = 24.hours
  SUPPORTED_INPUT_ENCODINGS = %w[UTF-8 UTF-8-BOM Windows-31J].freeze
  SUPPORTED_OUTPUT_ENCODINGS = %w[UTF-8 UTF-8-BOM Windows-31J].freeze
end

FileUtils.mkdir_p(CsvTool::TEMP_DIR)

require Rails.root.join("app/services/csv_tool/errors")
