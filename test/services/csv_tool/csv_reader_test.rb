# frozen_string_literal: true

require "test_helper"

class CsvTool::CsvReaderTest < ActiveSupport::TestCase
  SAMPLE_PATH = Rails.root.join("test/fixtures/files/sample_utf8.csv")

  test "reads sample csv with headers preview and counts" do
    result = CsvTool::CsvReader.new(SAMPLE_PATH.read).read!

    assert_equal %w[利用者番号 氏名 生年月日 住所 電話番号], result.headers
    assert_equal 4, result.row_count
    assert_equal 5, result.column_count
    assert_equal 4, result.preview_rows.size
    assert_equal "山田太郎", result.preview_rows.first[1]
    assert_equal "鈴木,一郎", result.rows.last[1]
    assert_empty result.warnings
  end

  test "reads comma in quoted value" do
    content = "name,note\n\"鈴木,一郎\",comma included\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_equal "鈴木,一郎", result.rows.first[0]
    assert_equal "comma included", result.rows.first[1]
  end

  test "reads double quotes in value" do
    content = "name,note\n\"山田\"\"太郎\",quoted\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_equal "山田\"太郎", result.rows.first[0]
  end

  test "reads cell with newline" do
    content = "name,note\nfoo,\"line1\nline2\"\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_equal "line1\nline2", result.rows.first[1]
  end

  test "trims header whitespace" do
    content = " name , note \nfoo,bar\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_equal %w[name note], result.headers
    assert_equal "foo", result.rows.first[0]
  end

  test "reads header only csv as zero rows" do
    content = "name,note\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_equal 0, result.row_count
    assert_equal 2, result.column_count
    assert_empty result.preview_rows
  end

  test "warns and keeps duplicated headers" do
    content = "name,name\nfoo,bar\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_includes result.warnings, "ヘッダー名が重複しています。列の区別には表の列記号（A, B, C…）を使用してください。"
    assert_equal %w[name name], result.headers
    assert_equal "foo", result.rows.first[0]
    assert_equal "bar", result.rows.first[1]
  end

  test "keeps duplicated numeric headers as separate columns" do
    content = "3,3,2,2,2\na,b,c,d,e\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_equal %w[3 3 2 2 2], result.headers
    assert_equal %w[a b c d e], result.rows.first
  end

  test "warns when row column count differs from header" do
    content = "name,note\nonly-one-column\nfoo,bar,baz\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_includes result.warnings, "列数が行によって異なる行があります。不足分は空欄として扱います。"
    assert_nil result.rows.first[1]
    assert_equal "foo", result.rows.second[0]
  end

  test "raises NoHeaderError for empty content" do
    error = assert_raises(CsvTool::NoHeaderError) do
      CsvTool::CsvReader.new("").read!
    end

    assert_equal "empty content", error.message
  end

  test "raises NoHeaderError when header row is blank" do
    assert_raises(CsvTool::NoHeaderError) do
      CsvTool::CsvReader.new(",,\nfoo,bar\n").read!
    end
  end

  test "raises InvalidCsvError for malformed csv" do
    error = assert_raises(CsvTool::InvalidCsvError) do
      CsvTool::CsvReader.new("name,note\n\"unclosed\n").read!
    end

    assert_match(/unclosed/i, error.message)
    assert_equal "CSV形式が正しくありません", error.user_message
  end

  test "limits preview rows" do
    rows = (1..15).map { |i| "row#{i},value#{i}" }.join("\n")
    content = "name,note\n#{rows}\n"

    result = CsvTool::CsvReader.new(content).read!

    assert_equal 15, result.row_count
    assert_equal CsvTool::PREVIEW_ROW_LIMIT, result.preview_rows.size
  end
end
