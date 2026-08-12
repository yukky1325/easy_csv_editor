# frozen_string_literal: true

require "csv"

module CsvTool
  class CsvReader
    ReadResult = Struct.new(
      :headers,
      :rows,
      :preview_rows,
      :row_count,
      :column_count,
      :warnings,
      keyword_init: true
    )

    def initialize(utf8_content)
      @utf8_content = utf8_content.to_s
    end

    def read!
      raise NoHeaderError, "empty content" if utf8_content.blank?

      table = parse_table
      raise NoHeaderError, "no header row" if table.empty?

      headers = normalize_headers(table.first)
      raise NoHeaderError, "header row is blank" if headers.all?(&:empty?)

      warnings = build_header_warnings(headers)
      rows, row_warnings = build_rows(headers, table[1..] || [])
      warnings.concat(row_warnings)

      preview_rows = rows.first(PREVIEW_ROW_LIMIT)

      ReadResult.new(
        headers: headers,
        rows: rows,
        preview_rows: preview_rows,
        row_count: rows.size,
        column_count: headers.size,
        warnings: warnings
      )
    end

    private

    attr_reader :utf8_content

    def parse_table
      CSV.parse(utf8_content, liberal_parsing: false)
    rescue CSV::MalformedCSVError => e
      raise InvalidCsvError, e.message
    end

    def normalize_headers(header_row)
      header_row.map { |header| normalize_cell(header).to_s.strip }
    end

    def build_header_warnings(headers)
      warnings = []
      if headers.size != headers.uniq.size
        warnings << "ヘッダー名が重複しています。列の区別には表の列記号（A, B, C…）を使用してください。"
      end
      warnings
    end

    def build_rows(headers, data_rows)
      warnings = []
      variable_width = false

      rows = data_rows.map do |fields|
        fields ||= []
        variable_width = true if fields.size != headers.size

        headers.each_index.map { |index| normalize_cell(fields[index]) }.freeze
      end

      if variable_width
        warnings << "列数が行によって異なる行があります。不足分は空欄として扱います。"
      end

      [rows, warnings]
    end

    def normalize_cell(value)
      return nil if value.nil?

      value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
  end
end
