# frozen_string_literal: true

class CsvUploadForm
  include ActiveModel::Model

  attr_accessor :file

  validate :validate_file_with_service

  private

  def validate_file_with_service
    CsvTool::CsvFileValidator.new(file).validate!
  rescue CsvTool::Error => e
    errors.add(:file, e.user_message)
  end
end
