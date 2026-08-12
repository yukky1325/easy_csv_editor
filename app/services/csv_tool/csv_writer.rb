# frozen_string_literal: true

require "csv"

module CsvTool
  class CsvWriter
    WriteResult = Struct.new(:content, :encoding, :warnings, keyword_init: true)

    def initialize(headers:, rows:)
      @headers = headers
      @rows = rows
      @warnings = []
    end

    def write!(output_encoding: "UTF-8")
      validate_output_encoding!(output_encoding)

      csv_string = generate_csv
      content = encode_csv(csv_string, output_encoding)

      WriteResult.new(
        content: content,
        encoding: output_encoding,
        warnings: warnings
      )
    end

    private

    attr_reader :headers, :rows, :warnings

    def validate_output_encoding!(output_encoding)
      return if SUPPORTED_OUTPUT_ENCODINGS.include?(output_encoding)

      raise EncodingConversionError, "unsupported encoding: #{output_encoding}"
    end

    def generate_csv
      CSV.generate(row_sep: "\r\n") do |csv|
        csv << headers.map { |header| sanitize_cell_value(header) }
        rows.each do |row|
          csv << headers.each_index.map { |index| sanitize_cell_value(row_value(row, index)) }
        end
      end
    end

    def row_value(row, index)
      return row[index] if row.is_a?(Array)

      row[headers[index]] || row[headers[index].to_s]
    end

    DANGEROUS_CELL_PREFIX_PATTERN = /\A[=+\-@]/

    def sanitize_cell_value(value)
      return value if value.nil?

      string = value.to_s
      return string unless string.match?(DANGEROUS_CELL_PREFIX_PATTERN)

      "'#{string}"
    end

    def encode_csv(csv_string, output_encoding)
      utf8_binary = csv_string.encode(Encoding::UTF_8).b

      case output_encoding
      when "UTF-8"
        utf8_binary
      when "UTF-8-BOM"
        CsvEncodingDetector::UTF8_BOM + utf8_binary
      when "Windows-31J"
        encode_to_windows_31j(utf8_binary)
      else
        raise EncodingConversionError, "unsupported encoding: #{output_encoding}"
      end
    end

    def encode_to_windows_31j(utf8_binary)
      utf8_string = utf8_binary.dup.force_encoding(Encoding::UTF_8)
      replacement_count = count_windows_31j_replacements(utf8_string)

      encoded = utf8_string.encode(
        Encoding::Windows_31J,
        invalid: :replace,
        undef: :replace,
        replace: "?"
      )

      add_replacement_warning!(replacement_count)
      encoded.b
    end

    def count_windows_31j_replacements(utf8_string)
      utf8_string.each_char.count do |char|
        !windows_31j_convertible?(char)
      end
    end

    def windows_31j_convertible?(char)
      char.encode(Encoding::Windows_31J)
      true
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      false
    end

    def add_replacement_warning!(count)
      return if count.zero?

      warnings << "Windows-31J に変換できない文字が #{count} 件、? に置換しました"
    end
  end
end
