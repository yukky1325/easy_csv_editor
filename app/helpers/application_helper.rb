# frozen_string_literal: true

module ApplicationHelper
  APP_NAME = "easy_csv_editor"

  def app_name
    APP_NAME
  end

  def app_title(page_title = nil)
    page_title.present? ? "#{page_title} - #{APP_NAME}" : APP_NAME
  end
end
