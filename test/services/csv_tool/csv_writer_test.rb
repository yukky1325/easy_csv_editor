# frozen_string_literal: true

require "csv"
require "test_helper"

class CsvTool::CsvWriterTest < ActiveSupport::TestCase
  setup do
    read_result = CsvTool::CsvReader.new(Rails.root.join("test/fixtures/files/sample_utf8.csv").read).read!
    process_result = CsvTool::CsvProcessor.new(
      headers: read_result.headers,
      rows: read_result.rows
    ).process!(selected_columns: [0, 1, 4])

    @writer = CsvTool::CsvWriter.new(
      headers: process_result.headers,
      rows: process_result.rows
    )
  end

  test "writes UTF-8 csv binary" do
    result = @writer.write!(output_encoding: "UTF-8")

    assert_equal "UTF-8", result.encoding
    assert_equal Encoding::ASCII_8BIT, result.content.encoding
    assert_empty result.warnings

    csv_text = result.content.dup.force_encoding(Encoding::UTF_8)
    parsed = CSV.parse(csv_text, headers: true)

    assert_equal %w[利用者番号 氏名 電話番号], parsed.headers
    assert_equal 4, parsed.size
    assert_equal "山田太郎", parsed[0]["氏名"]
    assert_equal "鈴木,一郎", parsed[3]["氏名"]
  end

  test "uses CRLF line endings" do
    result = @writer.write!(output_encoding: "UTF-8")

    csv_text = result.content.dup.force_encoding(Encoding::UTF_8)
    assert_includes csv_text, "\r\n"
    assert_not_includes csv_text, "\r\n\r\n"
  end

  test "does not include UTF-8 BOM" do
    result = @writer.write!(output_encoding: "UTF-8")

    refute result.content.start_with?(CsvTool::CsvEncodingDetector::UTF8_BOM)
  end

  test "writes UTF-8 BOM csv binary" do
    result = @writer.write!(output_encoding: "UTF-8-BOM")

    assert_equal "UTF-8-BOM", result.encoding
    assert result.content.start_with?(CsvTool::CsvEncodingDetector::UTF8_BOM)

    csv_text = result.content.byteslice(3..).force_encoding(Encoding::UTF_8)
    parsed = CSV.parse(csv_text, headers: true)

    assert_equal %w[利用者番号 氏名 電話番号], parsed.headers
    assert_equal 4, parsed.size
  end

  test "quotes values containing commas" do
    writer = CsvTool::CsvWriter.new(
      headers: %w[name note],
      rows: [["鈴木,一郎", "comma"]]
    )

    csv_text = writer.write!(output_encoding: "UTF-8").content.dup.force_encoding(Encoding::UTF_8)

    assert_includes csv_text, "\"鈴木,一郎\""
  end

  test "writes csv with empty header names" do
    writer = CsvTool::CsvWriter.new(
      headers: ["name", "", "age"],
      rows: [["foo", "bar", "baz"]]
    )

    csv_text = writer.write!(output_encoding: "UTF-8").content.dup.force_encoding(Encoding::UTF_8)

    assert_includes csv_text, "name,"
    assert_includes csv_text, ",age"
    assert_includes csv_text, "foo,bar,baz"
  end

  test "writes csv with duplicated header names" do
    writer = CsvTool::CsvWriter.new(
      headers: %w[3 3 2],
      rows: [["a", "b", "c"]]
    )

    csv_text = writer.write!(output_encoding: "UTF-8").content.dup.force_encoding(Encoding::UTF_8)

    assert_equal "3,3,2\r\na,b,c\r\n", csv_text
  end

  test "prefixes dangerous cell values with single quote" do
    writer = CsvTool::CsvWriter.new(
      headers: %w[formula note],
      rows: [
        ["=1+1", "+value"],
        ["-minus", "@mention"],
        ["normal", nil]
      ]
    )

    parsed = CSV.parse(
      writer.write!(output_encoding: "UTF-8").content.dup.force_encoding(Encoding::UTF_8),
      headers: true
    )

    assert_equal "'=1+1", parsed[0]["formula"]
    assert_equal "'+value", parsed[0]["note"]
    assert_equal "'-minus", parsed[1]["formula"]
    assert_equal "'@mention", parsed[1]["note"]
    assert_equal "normal", parsed[2]["formula"]
    assert_nil parsed[2]["note"]
  end

  test "raises EncodingConversionError for unsupported encoding" do
    error = assert_raises(CsvTool::EncodingConversionError) do
      @writer.write!(output_encoding: "EUC-JP")
    end

    assert_match "unsupported encoding", error.message
    assert_equal "文字コードの変換に失敗しました", error.user_message
  end

  test "writes Windows-31J csv binary" do
    result = @writer.write!(output_encoding: "Windows-31J")

    assert_equal "Windows-31J", result.encoding
    assert_equal Encoding::ASCII_8BIT, result.content.encoding
    assert_empty result.warnings

    csv_text = result.content.dup.force_encoding(Encoding::Windows_31J).encode(Encoding::UTF_8)
    parsed = CSV.parse(csv_text, headers: true)

    assert_equal %w[利用者番号 氏名 電話番号], parsed.headers
    assert_equal "山田太郎", parsed[0]["氏名"]
  end

  test "replaces unmappable characters and adds warning for Windows-31J" do
    writer = CsvTool::CsvWriter.new(
      headers: %w[name],
      rows: [["テスト😀"]]
    )

    result = writer.write!(output_encoding: "Windows-31J")

    csv_text = result.content.dup.force_encoding(Encoding::Windows_31J).encode(Encoding::UTF_8)
    assert_includes csv_text, "テスト?"
    assert_equal 1, result.warnings.size
    assert_includes result.warnings.first, "Windows-31J に変換できない文字が 1 件、? に置換しました"
  end
end
