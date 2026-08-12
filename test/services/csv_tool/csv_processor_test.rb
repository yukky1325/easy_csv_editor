# frozen_string_literal: true

require "test_helper"

class CsvTool::CsvProcessorTest < ActiveSupport::TestCase
  ID = 0
  NAME = 1
  BIRTHDAY = 2
  ADDRESS = 3
  PHONE = 4

  setup do
    @read_result = CsvTool::CsvReader.new(Rails.root.join("test/fixtures/files/sample_utf8.csv").read).read!
    @processor = CsvTool::CsvProcessor.new(
      headers: @read_result.headers,
      rows: @read_result.rows
    )
  end

  test "extracts only selected columns" do
    result = @processor.process!(selected_columns: [ID, NAME, PHONE])

    assert_equal %w[利用者番号 氏名 電話番号], result.headers
    assert_equal 4, result.rows.size
    assert_equal %w[0001 山田太郎 03-0000-0001], result.rows.first
  end

  test "keeps original column order" do
    result = @processor.process!(selected_columns: [PHONE, ID, NAME])

    assert_equal %w[利用者番号 氏名 電話番号], result.headers
  end

  test "raises NoColumnsSelectedError when no columns are selected" do
    error = assert_raises(CsvTool::NoColumnsSelectedError) do
      @processor.process!(selected_columns: [])
    end

    assert_equal "no columns selected", error.message
    assert_equal "出力する列を 1 つ以上選択してください", error.user_message
  end

  test "raises ColumnNotFoundError when unknown column is selected" do
    error = assert_raises(CsvTool::ColumnNotFoundError) do
      @processor.process!(selected_columns: [ID, 99])
    end

    assert_match "unknown columns", error.message
    assert_equal "指定された列が CSV に存在しません", error.user_message
  end

  test "ignores blank values in selected columns array" do
    result = @processor.process!(selected_columns: [ID, "", NAME])

    assert_equal %w[利用者番号 氏名], result.headers
  end

  test "removes completely empty rows when option is enabled" do
    headers = %w[利用者番号 氏名]
    rows = [
      %w[0001 山田太郎],
      [nil, nil],
      ["", "   "],
      %w[0002 佐藤花子]
    ]
    processor = CsvTool::CsvProcessor.new(headers: headers, rows: rows)

    result = processor.process!(selected_columns: [0, 1], remove_empty_rows: true)

    assert_equal 2, result.rows.size
    assert_equal "0001", result.rows.first[0]
    assert_equal "0002", result.rows.last[0]
  end

  test "keeps empty rows when option is disabled" do
    headers = %w[利用者番号 氏名]
    rows = [
      %w[0001 山田太郎],
      [nil, ""]
    ]
    processor = CsvTool::CsvProcessor.new(headers: headers, rows: rows)

    result = processor.process!(selected_columns: [0, 1], remove_empty_rows: false)

    assert_equal 2, result.rows.size
  end

  test "does not remove row that has data only in non-selected columns" do
    headers = %w[利用者番号 氏名 住所]
    rows = [
      [nil, nil, "東京都"]
    ]
    processor = CsvTool::CsvProcessor.new(headers: headers, rows: rows)

    result = processor.process!(selected_columns: [ID, NAME], remove_empty_rows: true)

    assert_equal 1, result.rows.size
    assert_equal [nil, nil], result.rows.first
  end

  test "removes rows where specified column is blank" do
    result = @processor.process!(
      selected_columns: [ID, NAME, PHONE],
      blank_column: ID
    )

    assert_equal 3, result.rows.size
    assert result.rows.none? { |row| row[NAME] == "番号なし利用者" }
    assert_equal "0001", result.rows.first[0]
    assert_equal "0004", result.rows.last[0]
  end

  test "raises ColumnNotFoundError when blank_column does not exist" do
    error = assert_raises(CsvTool::ColumnNotFoundError) do
      @processor.process!(
        selected_columns: [ID, NAME],
        blank_column: "99"
      )
    end

    assert_match "blank column not found", error.message
    assert_equal "指定された列が CSV に存在しません", error.user_message
  end

  test "treats whitespace-only blank_column value as blank" do
    headers = %w[利用者番号 氏名]
    rows = [
      %w[0001 山田太郎],
      ["   ", "空白番号"]
    ]
    processor = CsvTool::CsvProcessor.new(headers: headers, rows: rows)

    result = processor.process!(selected_columns: [0, 1], blank_column: 0)

    assert_equal 1, result.rows.size
    assert_equal "0001", result.rows.first[0]
  end

  test "blank_column can be outside selected output columns" do
    result = @processor.process!(
      selected_columns: [NAME, PHONE],
      blank_column: ID
    )

    assert_equal %w[氏名 電話番号], result.headers
    assert_equal 3, result.rows.size
    assert result.rows.none? { |row| row[0] == "番号なし利用者" }
  end

  test "outputs selected columns in specified order" do
    result = @processor.process!(
      selected_columns: [ID, NAME, PHONE],
      column_order: [PHONE, NAME, ID, BIRTHDAY, ADDRESS]
    )

    assert_equal %w[電話番号 氏名 利用者番号], result.headers
    assert_equal %w[03-0000-0001 山田太郎 0001], result.rows.first
  end

  test "can produce zero rows after all filters" do
    headers = %w[利用者番号 氏名]
    rows = [["", "対象外"]]
    processor = CsvTool::CsvProcessor.new(headers: headers, rows: rows)

    result = processor.process!(
      selected_columns: [0, 1],
      remove_empty_rows: true,
      blank_column: 0
    )

    assert_equal 0, result.rows.size
  end

  test "renames output headers while keeping original values" do
    result = @processor.process!(
      selected_columns: [ID, NAME],
      column_labels: { "0" => "会員ID", "1" => "名前" }
    )

    assert_equal %w[会員ID 名前], result.headers
    assert_equal %w[0001 山田太郎], result.rows.first
  end

  test "allows duplicated output headers" do
    headers = %w[3 3 2]
    rows = [%w[a b c]]
    processor = CsvTool::CsvProcessor.new(headers: headers, rows: rows)

    result = processor.process!(
      selected_columns: [0, 1, 2],
      column_labels: { "0" => "3", "1" => "3", "2" => "2" }
    )

    assert_equal %w[3 3 2], result.headers
    assert_equal %w[a b c], result.rows.first
  end

  test "allows empty output header for empty source column" do
    headers = ["name", "", "age"]
    rows = [["a", "b", "c"]]
    processor = CsvTool::CsvProcessor.new(headers: headers, rows: rows)

    result = processor.process!(
      selected_columns: [0, 1, 2],
      column_labels: { "0" => "name", "1" => "", "2" => "age" }
    )

    assert_equal ["name", "", "age"], result.headers
    assert_equal %w[a b c], result.rows.first
  end
end
