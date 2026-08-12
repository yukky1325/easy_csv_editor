# frozen_string_literal: true

require "test_helper"

class CsvUploadFormTest < ActiveSupport::TestCase
  test "valid csv file is valid" do
    form = CsvUploadForm.new(
      file: build_uploaded_file(content: "name,value\nfoo,bar\n", filename: "sample.csv")
    )

    assert_predicate form, :valid?
    assert_empty form.errors
  end

  test "missing file is invalid" do
    form = CsvUploadForm.new(file: nil)

    assert_not form.valid?
    assert_includes form.errors[:file], "ファイルが選択されていません"
  end

  test "non-csv extension is invalid" do
    form = CsvUploadForm.new(
      file: build_uploaded_file(content: "name,value\n", filename: "sample.txt")
    )

    assert_not form.valid?
    assert_includes form.errors[:file], "CSVファイル（.csv）を選択してください"
  end

  test "empty file is invalid" do
    form = CsvUploadForm.new(
      file: build_uploaded_file(content: "", filename: "empty.csv")
    )

    assert_not form.valid?
    assert_includes form.errors[:file], "CSV形式が正しくありません"
  end

  test "file size exceeded is invalid" do
    form = CsvUploadForm.new(
      file: build_uploaded_file(
        content: "a" * (CsvTool::MAX_FILE_SIZE + 1),
        filename: "large.csv"
      )
    )

    assert_not form.valid?
    assert_includes form.errors[:file], "ファイルサイズが上限（5MB）を超えています"
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
