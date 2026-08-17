# frozen_string_literal: true

module ApplicationHelper
  APP_NAME = "easy_csv_editor"
  APP_DISPLAY_NAME = "Easy CSV Editor"

  def app_name
    APP_NAME
  end

  def app_display_name
    APP_DISPLAY_NAME
  end

  def app_title(page_title = nil)
    page_title.present? ? "#{page_title} - #{APP_DISPLAY_NAME}" : APP_DISPLAY_NAME
  end
end
