# frozen_string_literal: true

require "test_helper"

class CsvProcessingFormTest < ActiveSupport::TestCase
  HEADERS = %w[利用者番号 氏名 生年月日 住所 電話番号].freeze

  test "valid processing options" do
    form = build_form(
      selected_columns: %w[0 1],
      remove_empty_rows: "1",
      blank_column: "0",
      output_encoding: "UTF-8"
    )

    assert_predicate form, :valid?
    assert_empty form.errors
    assert form.remove_empty_rows?
    assert_equal [0, 1], form.selected_column_indices
  end

  test "invalid when no columns are selected" do
    form = build_form(selected_columns: [])

    assert_not form.valid?
    assert_includes form.errors[:selected_columns], "出力する列を 1 つ以上選択してください"
  end

  test "invalid when unknown column is selected" do
    form = build_form(selected_columns: %w[0 99])

    assert_not form.valid?
    assert_includes form.errors[:selected_columns], "指定された列が CSV に存在しません"
  end

  test "invalid when blank column does not exist" do
    form = build_form(blank_column: "99")

    assert_not form.valid?
    assert_includes form.errors[:blank_column], "指定された列が CSV に存在しません"
  end

  test "allows blank column to be unspecified" do
    form = build_form(blank_column: "")

    assert_predicate form, :valid?
  end

  test "invalid when output encoding is missing" do
    form = build_form(output_encoding: "")

    assert_not form.valid?
    assert_includes form.errors[:output_encoding], "出力文字コードを選択してください"
  end

  test "invalid when output encoding is unsupported" do
    form = build_form(output_encoding: "EUC-JP")

    assert_not form.valid?
    assert_includes form.errors[:output_encoding], "選択できない出力文字コードです"
  end

  test "casts remove_empty_rows checkbox value" do
    form = build_form(remove_empty_rows: "0")

    assert_not form.remove_empty_rows?
  end

  test "allows empty output column labels" do
    form = build_form(
      headers: ["name", "", "age"],
      selected_columns: %w[0 1 2],
      column_labels_json: { "0" => "name", "1" => "", "2" => "age" }.to_json
    )

    assert_predicate form, :valid?
  end

  test "allows duplicated output column labels" do
    form = build_form(
      selected_columns: %w[0 1],
      column_labels_json: { "0" => "同じ名前", "1" => "同じ名前" }.to_json
    )

    assert_predicate form, :valid?
  end

  test "builds column label mapping from column_labels_json" do
    form = build_form(
      selected_columns: %w[0 1],
      column_labels_json: { "0" => "会員ID", "1" => "氏名" }.to_json
    )

    assert_equal({ "0" => "会員ID", "1" => "氏名" }, form.column_labels_for_processor)
  end

  test "invalid column_labels_json is invalid" do
    form = build_form(column_labels_json: "not json")

    assert_not form.valid?
    assert_includes form.errors[:column_labels_json], "列名の編集内容が正しくありません"
  end

  test "builds column label mapping for processor" do
    form = build_form(
      selected_columns: %w[0 1],
      column_labels: { "0" => "会員ID", "1" => "氏名" }
    )

    assert_equal({ "0" => "会員ID", "1" => "氏名" }, form.column_labels_for_processor)
  end

  test "allows fewer edited rows than original row count" do
    edited_rows = [
      %w[0001 編集後 1950-01-01 東京都千代田区 03-0000-0001]
    ]
    form = build_form(
      edited_rows_json: edited_rows.to_json,
      row_count: 4,
      headers: HEADERS
    )

    assert_predicate form, :valid?

    rows = form.rows_for_processing(default_rows: [%w[0001 山田太郎]])
    assert_equal 1, rows.size
    assert_equal "編集後", rows.first[1]
  end

  test "invalid when edited rows json is empty array" do
    form = build_form(edited_rows_json: [].to_json, row_count: 4)

    assert_not form.valid?
    assert_includes form.errors[:edited_rows_json], "データの編集内容が正しくありません"
  end

  test "uses edited rows when edited_rows_json is present" do
    edited_rows = [
      %w[0001 編集後 1950-01-01 東京都千代田区 03-0000-0001]
    ]
    form = build_form(
      edited_rows_json: edited_rows.to_json,
      row_count: 1,
      headers: HEADERS
    )

    default_rows = [%w[0001 山田太郎]]
    rows = form.rows_for_processing(default_rows: default_rows)

    assert_equal "編集後", rows.first[1]
  end

  test "invalid edited_rows_json is invalid" do
    form = build_form(edited_rows_json: "not json", row_count: 4)

    assert_not form.valid?
    assert_includes form.errors[:edited_rows_json], "データの編集内容が正しくありません"
  end

  private

  def build_form(**attributes)
    defaults = {
      selected_columns: %w[0 1],
      remove_empty_rows: "1",
      blank_column: "",
      output_encoding: "UTF-8",
      headers: HEADERS
    }

    CsvProcessingForm.new(defaults.merge(attributes))
  end
end
