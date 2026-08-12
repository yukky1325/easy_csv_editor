# frozen_string_literal: true

require "test_helper"

class CsvFilesControllerTest < ActionDispatch::IntegrationTest
  test "GET / shows upload page" do
    get root_url
    assert_response :success
    assert_match "CSVファイルのアップロード", response.body
    assert_select "form[enctype=?]", "multipart/form-data"
    assert_select "input[type=file][accept='.csv']"
    assert_select "input[type=submit][value=?]", "アップロード"
    assert_match "#{(CsvTool::MAX_FILE_SIZE / 1.megabyte).round}MB", response.body
  end

  test "POST /csv_files with valid csv redirects to preview" do
    post csv_files_url, params: { csv_upload_form: { file: sample_csv_upload } }

    assert_response :redirect
    assert_match %r{/csv_files/[0-9a-f-]{36}/preview}, response.redirect_url

    follow_redirect!
    assert_response :success
    assert_match "CSVプレビュー・加工条件", response.body
    assert_match "sample_utf8.csv", response.body
    assert_match "4 行 × 5 列", response.body
    assert_match "全 4 行を表示", response.body
    assert_match "利用者番号", response.body
    assert_match "山田太郎", response.body
    assert_select "table.csv-spreadsheet"
    assert_select "input[name='csv_processing_form[selected_columns][]']", count: 5
    assert_select "input[data-csv-preview-target='rowCheckbox']", count: 4
    assert_select "input[name^='csv_processing_form[column_labels_json]']"
    assert_select "button", text: "全選択", count: 2
    assert_select "button", text: "全解除", count: 2
    assert_select "table.csv-spreadsheet[style*='width: 714px']"
    assert_select "tr.csv-column-name-row th.csv-column-name-cell[contenteditable='true']", count: 5
    assert_select "th.csv-column-name-cell", text: "利用者番号"
    assert_select "th.csv-column-name-cell", text: "氏名"
    assert_select "th.csv-row-num", minimum: 2
    assert_select "input#csv_processing_form_remove_empty_rows"
    assert_select "select#csv_processing_form_blank_column"
    assert_select "select#csv_processing_form_blank_column option", text: "A"
    assert_select "input[type=radio][name='csv_processing_form[output_encoding]']", count: 3
    assert_select "a", text: "戻る"
    assert_select "input[type=submit][value=?]", "加工を実行"
  end

  test "POST /csv_files without file redirects to root with alert" do
    post csv_files_url, params: { csv_upload_form: { file: nil } }

    assert_redirected_to root_path
    assert_equal "ファイルが選択されていません", flash[:alert]
  end

  test "POST /csv_files with invalid extension shows flash alert" do
    post csv_files_url, params: {
      csv_upload_form: { file: uploaded_csv("name,value\n", "sample.txt") }
    }

    assert_redirected_to root_path
    follow_redirect!

    assert_select ".alert-danger", text: /CSVファイル（\.csv）を選択してください/
  end

  test "POST /csv_files with empty file shows flash alert" do
    post csv_files_url, params: {
      csv_upload_form: { file: uploaded_csv("", "empty.csv") }
    }

    assert_redirected_to root_path
    follow_redirect!

    assert_select ".alert-danger", text: /CSV形式が正しくありません/
  end

  test "POST /csv_files with csv without header shows flash alert" do
    post csv_files_url, params: {
      csv_upload_form: { file: uploaded_csv(",,\nfoo,bar\n", "no_header.csv") }
    }

    assert_redirected_to root_path
    assert_equal "ヘッダー行が見つかりません", flash[:alert]
    follow_redirect!

    assert_select ".alert-danger", text: /ヘッダー行が見つかりません/
  end

  test "GET /csv_files/:token/preview without session redirects to root" do
    get preview_csv_file_url(token: SecureRandom.uuid)

    assert_redirected_to root_path
    assert_equal "セッションが切れました。最初からやり直してください", flash[:alert]
  end

  test "GET preview with mismatched session token redirects to root" do
    upload_and_get_token

    get preview_csv_file_url(token: SecureRandom.uuid)

    assert_redirected_to root_path
    assert_equal "セッションが切れました。最初からやり直してください", flash[:alert]
  end

  test "GET preview with invalid token format redirects to root" do
    upload_and_get_token

    get preview_csv_file_url(token: "not-a-valid-token")

    assert_redirected_to root_path
    assert_equal "セッションが切れました。最初からやり直してください", flash[:alert]
  end

  test "GET preview when tempfile is missing redirects to root" do
    token = upload_and_get_token
    CsvTool::CsvTempfileStore.new.delete!(token)

    get preview_csv_file_url(token: token)

    assert_redirected_to root_path
    assert_equal "セッションが切れました。最初からやり直してください", flash[:alert]
  end

  test "POST /csv_files/:token/process redirects to result" do
    token = upload_and_get_token

    post process_csv_file_url(token: token), params: processing_form_params

    assert_redirected_to result_csv_file_path(token: token)
  end

  test "POST process without selected columns redirects to preview with alert" do
    token = upload_and_get_token

    post process_csv_file_url(token: token), params: {
      csv_processing_form: {
        selected_columns: [],
        remove_empty_rows: "1",
        blank_column: "",
        output_encoding: "UTF-8"
      }
    }

    assert_redirected_to preview_csv_file_path(token: token)
    follow_redirect!

    assert_select ".alert-danger", text: /出力する列を 1 つ以上選択してください/
  end

  test "POST process that yields zero rows redirects to preview with alert" do
    post csv_files_url, params: {
      csv_upload_form: {
        file: uploaded_csv("利用者番号,氏名\n,対象外\n", "single_blank.csv")
      }
    }
    token = response.redirect_url.match(%r{/csv_files/([0-9a-f-]{36})/preview})[1]

    post process_csv_file_url(token: token), params: {
      csv_processing_form: {
        selected_columns: %w[0 1],
        remove_empty_rows: "1",
        blank_column: "0",
        output_encoding: "UTF-8"
      }
    }

    assert_redirected_to preview_csv_file_path(token: token)
    assert_equal "加工後のデータが 0 件です", flash[:alert]
  end

  test "GET /csv_files/:token/result without processing redirects to preview" do
    token = upload_and_get_token

    get result_csv_file_url(token: token)

    assert_redirected_to preview_csv_file_path(token: token)
    assert_equal "加工結果がありません。加工を実行してください。", flash[:alert]
  end

  test "GET download with mismatched token redirects to root" do
    token = upload_and_get_token
    post process_csv_file_url(token: token), params: processing_form_params

    get download_csv_file_url(token: SecureRandom.uuid)

    assert_redirected_to root_path
    assert_equal "セッションが切れました。最初からやり直してください", flash[:alert]
  end

  test "full processing flow shows stats and downloads csv" do
    token = upload_and_get_token

    post process_csv_file_url(token: token), params: processing_form_params
    follow_redirect!

    assert_response :success
    assert_match "加工完了", response.body
    assert_match "sample_utf8.csv", response.body
    assert_match "4 行", response.body
    assert_match "3 行", response.body
    assert_match "1 行", response.body
    assert_match "5 列", response.body
    assert_select "a[href=?]", download_csv_file_path(token: token)

    get download_csv_file_url(token: token)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/sample_utf8.*converted/, response.headers["Content-Disposition"])

    body = response.body.dup.force_encoding(Encoding::UTF_8)
    assert_includes body, "山田太郎"
    assert_not_includes body, "番号なし利用者"
  end

  test "download sanitizes csv injection payloads" do
    post csv_files_url, params: {
      csv_upload_form: {
        file: uploaded_csv("name,note\n=1+1,danger\n", "formula.csv")
      }
    }
    token = response.redirect_url.match(%r{/csv_files/([0-9a-f-]{36})/preview})[1]

    post process_csv_file_url(token: token), params: {
      csv_processing_form: {
        selected_columns: %w[0 1],
        remove_empty_rows: "0",
        blank_column: "",
        output_encoding: "UTF-8"
      }
    }

    get download_csv_file_url(token: token)

    body = response.body.dup.force_encoding(Encoding::UTF_8)
    assert_includes body, "'=1+1"
  end

  test "processing with renamed column headers writes renamed csv" do
    token = upload_and_get_token

    post process_csv_file_url(token: token), params: {
      csv_processing_form: processing_form_params[:csv_processing_form].merge(
        column_labels_json: {
          "0" => "会員ID",
          "1" => "氏名",
          "2" => "生年月日",
          "3" => "住所",
          "4" => "電話番号"
        }.to_json
      )
    }

    get download_csv_file_url(token: token)

    body = response.body.dup.force_encoding(Encoding::UTF_8)
    assert_includes body, "会員ID"
    assert_not_includes body, "利用者番号"
  end

  test "processing with subset of edited rows excludes unselected rows" do
    token = upload_and_get_token
    read_result = CsvTool::CsvReader.new(Rails.root.join("test/fixtures/files/sample_utf8.csv").read).read!
    selected_rows = [read_result.rows.first]

    post process_csv_file_url(token: token), params: {
      csv_processing_form: processing_form_params[:csv_processing_form].merge(
        edited_rows_json: selected_rows.to_json,
        row_count: read_result.row_count
      )
    }

    assert_redirected_to result_csv_file_path(token: token)

    get download_csv_file_url(token: token)

    body = response.body.dup.force_encoding(Encoding::UTF_8)
    assert_includes body, "山田太郎"
    assert_not_includes body, "佐藤花子"
  end

  test "invalid when edited rows json is empty array" do
    token = upload_and_get_token

    post process_csv_file_url(token: token), params: {
      csv_processing_form: processing_form_params[:csv_processing_form].merge(
        edited_rows_json: [].to_json,
        row_count: 4
      )
    }

    assert_redirected_to preview_csv_file_path(token: token)
    follow_redirect!
    assert_match "データの編集内容が正しくありません", response.body
  end

  test "processing with edited cell data writes edited csv" do
    token = upload_and_get_token
    read_result = CsvTool::CsvReader.new(Rails.root.join("test/fixtures/files/sample_utf8.csv").read).read!
    edited_rows = read_result.rows.map(&:dup)
    edited_rows[0][1] = "編集後太郎"

    post process_csv_file_url(token: token), params: {
      csv_processing_form: processing_form_params[:csv_processing_form].merge(
        edited_rows_json: edited_rows.to_json
      )
    }

    get download_csv_file_url(token: token)

    body = response.body.dup.force_encoding(Encoding::UTF_8)
    assert_includes body, "編集後太郎"
    assert_not_includes body, "山田太郎"
  end

  test "preview renders editable data cells" do
    post csv_files_url, params: { csv_upload_form: { file: sample_csv_upload } }
    follow_redirect!

    assert_select "td.csv-data-cell[contenteditable='true']", minimum: 1
  end

  test "processing with swapped column order writes csv in new order" do
    token = upload_and_get_token
    read_result = CsvTool::CsvReader.new(Rails.root.join("test/fixtures/files/sample_utf8.csv").read).read!
    column_order = [1, 0, 2, 3, 4]

    post process_csv_file_url(token: token), params: {
      csv_processing_form: processing_form_params[:csv_processing_form].merge(
        column_order: column_order.to_json,
        edited_rows_json: read_result.rows.to_json
      )
    }

    get download_csv_file_url(token: token)

    body = response.body.dup.force_encoding(Encoding::UTF_8)
    header_line = body.lines.first.to_s.delete("\r\n")
    assert_equal "氏名,利用者番号,生年月日,住所,電話番号", header_line
  end

  test "POST process succeeds when column headers contain brackets" do
    post csv_files_url, params: {
      csv_upload_form: {
        file: uploaded_csv("col[a],col[b]\n1,2\n", "brackets.csv")
      }
    }
    token = response.redirect_url.match(%r{/csv_files/([0-9a-f-]{36})/preview})[1]

    post process_csv_file_url(token: token), params: {
      csv_processing_form: {
        selected_columns: %w[0 1],
        remove_empty_rows: "0",
        blank_column: "",
        output_encoding: "UTF-8",
        column_labels_json: { "0" => "列A", "1" => "列B" }.to_json,
        edited_rows_json: "",
        column_order: [0, 1].to_json
      }
    }

    assert_redirected_to result_csv_file_path(token: token)
  end

  test "re-uploading processed csv succeeds" do
    token = upload_and_get_token

    post process_csv_file_url(token: token), params: processing_form_params
    get download_csv_file_url(token: token)
    processed_body = response.body.b

    post csv_files_url, params: {
      csv_upload_form: {
        file: uploaded_csv(processed_body, "processed_roundtrip.csv")
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match "CSVプレビュー・加工条件", response.body
    assert_match "processed_roundtrip.csv", response.body
    assert_match "山田太郎", response.body
  end

  test "POST process succeeds when csv has duplicated header names" do
    post csv_files_url, params: {
      csv_upload_form: {
        file: uploaded_csv("283010,A2,3,3,2,2,2,1\nv1,v2,a,b,c,d,e,f\n", "duplicate_headers.csv")
      }
    }
    token = response.redirect_url.match(%r{/csv_files/([0-9a-f-]{36})/preview})[1]

    post process_csv_file_url(token: token), params: {
      csv_processing_form: {
        selected_columns: %w[0 1 2 3 4 5 6 7],
        remove_empty_rows: "0",
        blank_column: "",
        output_encoding: "UTF-8",
        column_labels_json: {
          "0" => "283010",
          "1" => "A2",
          "2" => "3",
          "3" => "3",
          "4" => "2",
          "5" => "2",
          "6" => "2",
          "7" => "1"
        }.to_json,
        edited_rows_json: "",
        column_order: [0, 1, 2, 3, 4, 5, 6, 7].to_json
      }
    }

    assert_redirected_to result_csv_file_path(token: token)
  end

  test "POST process succeeds when csv has empty header columns" do
    post csv_files_url, params: {
      csv_upload_form: {
        file: uploaded_csv("name,,age\nfoo,bar,baz\n", "empty_header.csv")
      }
    }
    token = response.redirect_url.match(%r{/csv_files/([0-9a-f-]{36})/preview})[1]

    post process_csv_file_url(token: token), params: {
      csv_processing_form: {
        selected_columns: %w[0 1 2],
        remove_empty_rows: "0",
        blank_column: "",
        output_encoding: "UTF-8",
        column_labels_json: { "0" => "name", "1" => "", "2" => "age" }.to_json,
        edited_rows_json: "",
        column_order: [0, 1, 2].to_json
      }
    }

    assert_redirected_to result_csv_file_path(token: token)
  end

  test "preview renders row sort panel" do
    post csv_files_url, params: { csv_upload_form: { file: sample_csv_upload } }
    follow_redirect!

    assert_select "details.csv-row-sort-panel summary", text: "行の並べ替え（ソート）"
    assert_select "button[data-row-sort-mode='text-asc']"
    assert_select "button", text: "元の行順に戻す"
  end

  test "preview renders column move buttons" do
    post csv_files_url, params: { csv_upload_form: { file: sample_csv_upload } }
    follow_redirect!

    assert_select "button[title='左へ移動']", minimum: 1
    assert_select "button[title='右へ移動']", minimum: 1
  end

  private

  def sample_csv_upload
    fixture_file_upload("sample_utf8.csv", "text/csv")
  end

  def upload_and_get_token
    post csv_files_url, params: { csv_upload_form: { file: sample_csv_upload } }
    assert_response :redirect

    response.redirect_url.match(%r{/csv_files/([0-9a-f-]{36})/preview})[1]
  end

  def processing_form_params
    {
      csv_processing_form: {
        selected_columns: %w[0 1 2 3 4],
        remove_empty_rows: "1",
        blank_column: "0",
        output_encoding: "UTF-8"
      }
    }
  end

  def uploaded_csv(content, filename)
    file = Tempfile.new(["upload", File.extname(filename)])
    file.binmode
    file.write(content)
    file.rewind

    Rack::Test::UploadedFile.new(file.path, "text/csv", true, original_filename: filename)
  end
end
