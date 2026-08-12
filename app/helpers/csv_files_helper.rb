# frozen_string_literal: true

module CsvFilesHelper
  def csv_max_file_size_label
    size_mb = (CsvTool::MAX_FILE_SIZE / 1.megabyte.to_f).round
    "#{size_mb}MB"
  end

  def csv_supported_input_encodings_label
    CsvTool::SUPPORTED_INPUT_ENCODINGS.join(" / ")
  end

  def csv_output_encoding_label(encoding)
    case encoding
    when "UTF-8-BOM"
      "UTF-8（BOM付き）"
    when "Windows-31J"
      "Windows-31J（Shift_JIS相当）"
    else
      encoding
    end
  end

  def csv_preview_cell(value)
    if value.blank?
      content_tag(:span, "（空欄）", class: "csv-cell-empty")
    else
      value
    end
  end

  def csv_converted_filename(original_filename)
    base = File.basename(original_filename.to_s, ".*")
    "#{base}_converted_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
  end

  def csv_download_content_type(output_encoding)
    case output_encoding
    when "Windows-31J"
      "text/csv; charset=Windows-31J"
    else
      "text/csv; charset=utf-8"
    end
  end

  def csv_column_label(index)
    label = +""
    i = index

    while i >= 0
      label.prepend((65 + (i % 26)).chr)
      i = (i / 26) - 1
    end

    label
  end

  def csv_blank_column_options(headers)
    [["（指定しない）", ""]] + Array(headers).each_with_index.map do |_header, index|
      [csv_column_label(index), index.to_s]
    end
  end

  CSV_SPREADSHEET_ROW_NUM_WIDTH = 64
  CSV_SPREADSHEET_COL_WIDTH = 130

  def csv_spreadsheet_table_width(column_count)
    CSV_SPREADSHEET_ROW_NUM_WIDTH + column_count * CSV_SPREADSHEET_COL_WIDTH
  end
end
