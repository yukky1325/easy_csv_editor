# frozen_string_literal: true

require "test_helper"

class CsvTool::CsvProcessingResultTest < ActiveSupport::TestCase
  setup do
    read_result = CsvTool::CsvReader.new(Rails.root.join("test/fixtures/files/sample_utf8.csv").read).read!
    @rows_before = read_result.row_count
    @process_result = CsvTool::CsvProcessor.new(
      headers: read_result.headers,
      rows: read_result.rows
    ).process!(
      selected_columns: [0, 1],
      remove_empty_rows: true,
      blank_column: "0"
    )
    @write_result = CsvTool::CsvWriter.new(
      headers: @process_result.headers,
      rows: @process_result.rows
    ).write!(output_encoding: "UTF-8")
  end

  test "builds result from processor and writer outputs" do
    result = CsvTool::CsvProcessingResult.build(
      rows_before: @rows_before,
      process_result: @process_result,
      write_result: @write_result,
      output_encoding: "UTF-8",
      original_filename: "sample_utf8.csv",
      reader_warnings: ["warning"]
    )

    assert_equal 4, result.rows_before
    assert_equal 3, result.rows_after
    assert_equal 1, result.rows_removed
    assert_equal 2, result.columns_count
    assert_equal "UTF-8", result.output_encoding
    assert_equal %w[warning], result.warnings
    assert_equal "sample_utf8.csv", result.original_filename
    assert_predicate result.output_content, :present?
  end

  test "to_session_hash excludes binary content" do
    result = CsvTool::CsvProcessingResult.build(
      rows_before: @rows_before,
      process_result: @process_result,
      write_result: @write_result,
      output_encoding: "UTF-8",
      original_filename: "sample_utf8.csv"
    )

    hash = result.to_session_hash

    assert_equal 3, hash[:rows_after]
    assert_not hash.key?(:output_content)
  end

  test "raises EmptyResultError when processed rows are zero" do
    empty_process = CsvTool::CsvProcessor.new(
      headers: %w[利用者番号],
      rows: CsvTool::CsvReader.new("利用者番号\n\n").read!.rows
    ).process!(
      selected_columns: [0],
      remove_empty_rows: true,
      blank_column: "0"
    )

    write_result = CsvTool::CsvWriter.new(
      headers: empty_process.headers,
      rows: empty_process.rows
    ).write!(output_encoding: "UTF-8")

    assert_raises(CsvTool::EmptyResultError) do
      CsvTool::CsvProcessingResult.build(
        rows_before: 1,
        process_result: empty_process,
        write_result: write_result,
        output_encoding: "UTF-8",
        original_filename: "empty.csv"
      )
    end
  end
end
