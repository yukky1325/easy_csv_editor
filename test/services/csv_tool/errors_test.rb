# frozen_string_literal: true

require "test_helper"

class CsvTool::ErrorsTest < ActiveSupport::TestCase
  ERROR_CLASSES = [
    CsvTool::FileNotSelectedError,
    CsvTool::InvalidExtensionError,
    CsvTool::FileSizeExceededError,
    CsvTool::InvalidCsvError,
    CsvTool::NoHeaderError,
    CsvTool::EncodingDetectionError,
    CsvTool::EncodingConversionError,
    CsvTool::ColumnNotFoundError,
    CsvTool::NoColumnsSelectedError,
    CsvTool::EmptyResultError,
    CsvTool::SessionExpiredError,
    CsvTool::UnexpectedError
  ].freeze

  test "all errors inherit from CsvTool::Error" do
    ERROR_CLASSES.each do |error_class|
      assert_operator error_class, :<, CsvTool::Error
    end
  end

  test "each error exposes user_message" do
    assert_equal "ファイルが選択されていません", CsvTool::FileNotSelectedError.new.user_message
    assert_equal "CSVファイル（.csv）を選択してください", CsvTool::InvalidExtensionError.new.user_message
    assert_equal "CSV形式が正しくありません", CsvTool::InvalidCsvError.new.user_message
    assert_equal "ヘッダー行が見つかりません", CsvTool::NoHeaderError.new.user_message
    assert_equal "文字コードを判定できませんでした", CsvTool::EncodingDetectionError.new.user_message
    assert_equal "文字コードの変換に失敗しました", CsvTool::EncodingConversionError.new.user_message
    assert_equal "指定された列が CSV に存在しません", CsvTool::ColumnNotFoundError.new.user_message
    assert_equal "出力する列を 1 つ以上選択してください", CsvTool::NoColumnsSelectedError.new.user_message
    assert_equal "加工後のデータが 0 件です", CsvTool::EmptyResultError.new.user_message
    assert_equal "セッションが切れました。最初からやり直してください", CsvTool::SessionExpiredError.new.user_message
    assert_equal "予期しないエラーが発生しました", CsvTool::UnexpectedError.new.user_message
  end

  test "FileSizeExceededError includes limit in user_message" do
    error = CsvTool::FileSizeExceededError.new
    assert_match(/5MB/, error.user_message)
    assert_match(/上限/, error.user_message)
  end

  test "errors can be raised and rescued" do
    assert_raises(CsvTool::InvalidCsvError) do
      raise CsvTool::InvalidCsvError, "malformed row at line 3"
    end
  end

  test "internal message is separate from user_message" do
    error = CsvTool::InvalidCsvError.new("malformed row at line 3")

    assert_equal "malformed row at line 3", error.message
    assert_equal "CSV形式が正しくありません", error.user_message
  end

  test "UnexpectedError wraps cause for logging" do
    cause = StandardError.new("boom")
    error = CsvTool::UnexpectedError.new(cause)

    assert_equal cause, error.cause_exception
    assert_match "StandardError: boom", error.message
    assert_equal "予期しないエラーが発生しました", error.user_message
  end
end
