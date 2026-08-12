# frozen_string_literal: true

require "test_helper"

class CsvTool::CsvFileValidatorTest < ActiveSupport::TestCase
  test "valid csv file passes validation" do
    uploaded_file = build_uploaded_file(
      content: "name,value\nfoo,bar\n",
      filename: "sample.csv"
    )

    assert CsvTool::CsvFileValidator.new(uploaded_file).validate!
  end

  test "csv extension is case insensitive" do
    uploaded_file = build_uploaded_file(
      content: "name,value\nfoo,bar\n",
      filename: "sample.CSV"
    )

    assert CsvTool::CsvFileValidator.new(uploaded_file).validate!
  end

  test "missing file raises FileNotSelectedError" do
    error = assert_raises(CsvTool::FileNotSelectedError) do
      CsvTool::CsvFileValidator.new(nil).validate!
    end

    assert_equal "uploaded file is missing", error.message
    assert_equal "ファイルが選択されていません", error.user_message
  end

  test "non-csv extension raises InvalidExtensionError" do
    uploaded_file = build_uploaded_file(
      content: "name,value\nfoo,bar\n",
      filename: "sample.txt",
      content_type: "text/plain"
    )

    error = assert_raises(CsvTool::InvalidExtensionError) do
      CsvTool::CsvFileValidator.new(uploaded_file).validate!
    end

    assert_match "invalid extension", error.message
    assert_equal "CSVファイル（.csv）を選択してください", error.user_message
  end

  test "does not trust mime type alone" do
    uploaded_file = build_uploaded_file(
      content: "name,value\nfoo,bar\n",
      filename: "sample.txt",
      content_type: "text/csv"
    )

    assert_raises(CsvTool::InvalidExtensionError) do
      CsvTool::CsvFileValidator.new(uploaded_file).validate!
    end
  end

  test "file size exceeded raises FileSizeExceededError" do
    uploaded_file = build_uploaded_file(
      content: "a" * (CsvTool::MAX_FILE_SIZE + 1),
      filename: "large.csv"
    )

    error = assert_raises(CsvTool::FileSizeExceededError) do
      CsvTool::CsvFileValidator.new(uploaded_file).validate!
    end

    assert_match "file size exceeded", error.message
    assert_match "5MB", error.user_message
  end

  test "empty file raises InvalidCsvError" do
    uploaded_file = build_uploaded_file(
      content: "",
      filename: "empty.csv"
    )

    error = assert_raises(CsvTool::InvalidCsvError) do
      CsvTool::CsvFileValidator.new(uploaded_file).validate!
    end

    assert_equal "empty file", error.message
    assert_equal "CSV形式が正しくありません", error.user_message
  end

  private

  def build_uploaded_file(content:, filename:, content_type: "text/csv")
    tempfile = Tempfile.new(["upload", File.extname(filename)])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: filename,
      type: content_type
    )
  end
end
