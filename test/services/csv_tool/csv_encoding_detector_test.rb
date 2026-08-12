# frozen_string_literal: true

require "test_helper"

class CsvTool::CsvEncodingDetectorTest < ActiveSupport::TestCase
  test "detects UTF-8 without BOM" do
    binary = "利用者番号,氏名\n0001,山田太郎\n".b

    detector = CsvTool::CsvEncodingDetector.new(binary).detect!

    assert_equal "UTF-8", detector.detected_encoding
    assert_equal Encoding::UTF_8, detector.utf8_content.encoding
    assert_includes detector.utf8_content, "山田太郎"
  end

  test "detects UTF-8 with BOM" do
    binary = CsvTool::CsvEncodingDetector::UTF8_BOM + "name,value\nfoo,bar\n".b

    detector = CsvTool::CsvEncodingDetector.new(binary).detect!

    assert_equal "UTF-8-BOM", detector.detected_encoding
    assert_equal Encoding::UTF_8, detector.utf8_content.encoding
    assert_not detector.utf8_content.start_with?("\uFEFF")
    assert_includes detector.utf8_content, "name,value"
  end

  test "detects Windows-31J" do
    binary = "利用者番号,氏名\n0001,山田太郎\n".encode(Encoding::Windows_31J).b

    detector = CsvTool::CsvEncodingDetector.new(binary).detect!

    assert_equal "Windows-31J", detector.detected_encoding
    assert_equal Encoding::UTF_8, detector.utf8_content.encoding
    assert_includes detector.utf8_content, "山田太郎"
  end

  test "reads from uploaded file" do
    uploaded_file = build_uploaded_file(
      content: "name,value\nfoo,bar\n",
      filename: "sample.csv"
    )

    detector = CsvTool::CsvEncodingDetector.new(uploaded_file).detect!

    assert_equal "UTF-8", detector.detected_encoding
    assert_includes detector.utf8_content, "foo,bar"
    assert_equal 0, uploaded_file.tempfile.pos
  end

  test "raises EncodingDetectionError when encoding cannot be detected" do
    binary = "\xFF\xFE\xFD\xFC".b

    error = assert_raises(CsvTool::EncodingDetectionError) do
      CsvTool::CsvEncodingDetector.new(binary).detect!
    end

    assert_equal "unable to detect encoding", error.message
    assert_equal "文字コードを判定できませんでした", error.user_message
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
