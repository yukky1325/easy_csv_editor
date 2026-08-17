# frozen_string_literal: true

require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "GET / shows landing page" do
    get root_url

    assert_response :success
    assert_match "Easy CSV Editor", response.body
    assert_match "CSVをアップロードして始める", response.body
    assert_match "できること", response.body
    assert_match "安心して使える設計", response.body
    assert_select "a[href=?]", new_csv_file_path
    assert_select "form[enctype=?]", "multipart/form-data", count: 0
  end
end
