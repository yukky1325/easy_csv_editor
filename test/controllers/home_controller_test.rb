# frozen_string_literal: true

require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "GET / shows landing page" do
    get root_url

    assert_response :success
    assert_match "面倒なCSV作業を", response.body
    assert_match "もっと軽やかに", response.body
    assert_match "CSVファイルを選んで始める", response.body
    assert_match "操作は、3ステップ", response.body
    assert_select "a[href=?]", new_csv_file_path
    assert_select "a[href=?]", "#how-it-works"
    assert_select "form[enctype=?]", "multipart/form-data", count: 0
  end
end
