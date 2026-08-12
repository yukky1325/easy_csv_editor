# frozen_string_literal: true

module CsvTool
  class CsvFileValidator
    def initialize(uploaded_file)
      @uploaded_file = uploaded_file
    end

    def validate!
      raise FileNotSelectedError, "uploaded file is missing" unless file_present?
      raise InvalidExtensionError, "invalid extension: #{original_filename}" unless csv_extension?
      raise FileSizeExceededError, "file size exceeded: #{file_size} bytes" unless within_size_limit?
      raise InvalidCsvError, "empty file" if empty_file?

      true
    end

    private

    attr_reader :uploaded_file

    def file_present?
      uploaded_file.present?
    end

    def original_filename
      uploaded_file.original_filename.to_s
    end

    def csv_extension?
      File.extname(original_filename).casecmp?(ALLOWED_EXTENSION)
    end

    def file_size
      uploaded_file.size.to_i
    end

    def within_size_limit?
      file_size <= MAX_FILE_SIZE
    end

    def empty_file?
      file_size.zero?
    end
  end
end
