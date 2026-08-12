# frozen_string_literal: true

module CsvTool
  class CsvProcessingResult
    attr_reader :rows_before, :rows_after, :rows_removed, :columns_count,
                :output_encoding, :warnings, :original_filename, :output_content

    def initialize(rows_before:, rows_after:, columns_count:, output_encoding:,
                   warnings:, original_filename:, output_content:)
      @rows_before = rows_before
      @rows_after = rows_after
      @rows_removed = rows_before - rows_after
      @columns_count = columns_count
      @output_encoding = output_encoding
      @warnings = warnings
      @original_filename = original_filename
      @output_content = output_content

      raise EmptyResultError, "processing result has zero rows" if rows_after.zero?
    end

    def self.build(rows_before:, process_result:, write_result:, output_encoding:, original_filename:,
                   reader_warnings: [])
      new(
        rows_before: rows_before,
        rows_after: process_result.rows.size,
        columns_count: process_result.headers.size,
        output_encoding: output_encoding,
        warnings: Array(reader_warnings) + write_result.warnings,
        original_filename: original_filename,
        output_content: write_result.content
      )
    end

    def to_session_hash
      {
        rows_before: rows_before,
        rows_after: rows_after,
        rows_removed: rows_removed,
        columns_count: columns_count,
        output_encoding: output_encoding,
        warnings: warnings
      }
    end
  end
end
