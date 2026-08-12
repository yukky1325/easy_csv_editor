# frozen_string_literal: true

require "test_helper"

class CsvTool::CsvTempfileStoreTest < ActiveSupport::TestCase
  setup do
    @base_dir = Rails.root.join("tmp", "csv_tool_test_#{Process.pid}")
    @store = CsvTool::CsvTempfileStore.new(base_dir: @base_dir)
    @token = @store.generate_token
  end

  teardown do
    FileUtils.rm_rf(@base_dir)
  end

  test "save_input and read_input" do
    content = "name,value\nfoo,bar\n"

    @store.save_input!(
      token: @token,
      content: content,
      original_filename: "sample.csv",
      detected_encoding: "UTF-8"
    )

    assert @store.exists?(@token)
    assert_equal content, @store.read_input(@token)
    assert_predicate @store.input_path(@token), :exist?
  end

  test "save_input writes metadata json" do
    @store.save_input!(
      token: @token,
      content: "name,value\nfoo,bar\n",
      original_filename: "sample.csv",
      detected_encoding: "UTF-8",
      row_count: 1,
      column_count: 2,
      headers: %w[name value]
    )

    meta = @store.read_meta(@token)

    assert_equal "sample.csv", meta[:original_filename]
    assert_equal "UTF-8", meta[:detected_encoding]
    assert_equal 1, meta[:row_count]
    assert_equal 2, meta[:column_count]
    assert_equal %w[name value], meta[:headers]
    assert meta[:saved_at].present?
  end

  test "save_output and read_output" do
    @store.save_input!(
      token: @token,
      content: "name,value\nfoo,bar\n",
      original_filename: "sample.csv",
      detected_encoding: "UTF-8"
    )
    @store.save_output!(token: @token, content: "converted,data\n")

    assert_equal "converted,data\n", @store.read_output(@token)
  end

  test "delete removes all files for token" do
    @store.save_input!(
      token: @token,
      content: "name,value\nfoo,bar\n",
      original_filename: "sample.csv",
      detected_encoding: "UTF-8"
    )
    @store.save_output!(token: @token, content: "converted,data\n")

    @store.delete!(@token)

    assert_not @store.exists?(@token)
    assert_not @store.input_path(@token).exist?
    assert_not @store.output_path(@token).exist?
    assert_not @store.meta_path(@token).exist?
  end

  test "rejects invalid token format" do
    assert_raises(ArgumentError) do
      @store.save_input!(
        token: "../etc/passwd",
        content: "name,value\n",
        original_filename: "sample.csv",
        detected_encoding: "UTF-8"
      )
    end
  end

  test "rejects unsafe original filename" do
    assert_raises(ArgumentError) do
      @store.save_input!(
        token: @token,
        content: "name,value\n",
        original_filename: "../../secret.csv",
        detected_encoding: "UTF-8"
      )
    end
  end

  test "raises SessionExpiredError when input file is missing" do
    error = assert_raises(CsvTool::SessionExpiredError) do
      @store.read_input(@token)
    end

    assert_match "file not found", error.message
    assert_equal "セッションが切れました。最初からやり直してください", error.user_message
  end

  test "raises SessionExpiredError when meta file is missing" do
    assert_raises(CsvTool::SessionExpiredError) do
      @store.read_meta(@token)
    end
  end

  test "does not use original filename in file path" do
    @store.save_input!(
      token: @token,
      content: "name,value\nfoo,bar\n",
      original_filename: "利用者一覧.csv",
      detected_encoding: "UTF-8"
    )

    assert_equal @base_dir.join("#{@token}_input.csv"), @store.input_path(@token)
    assert_not @base_dir.join("利用者一覧.csv").exist?
  end
end
