# frozen_string_literal: true

class CsvProcessingForm
  include ActiveModel::Model
  include CsvFilesHelper

  attr_accessor :selected_columns, :remove_empty_rows, :blank_column, :output_encoding, :headers,
                :column_labels, :column_labels_json, :edited_rows_json, :row_count, :column_order

  validate :validate_processing_options

  def remove_empty_rows?
    ActiveModel::Type::Boolean.new.cast(remove_empty_rows)
  end

  def selected_column_indices
    Array(selected_columns).filter_map do |value|
      next if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end

  def column_labels_for_processor
    parsed_column_labels
  end

  def column_order_for_processor(column_count:)
    order = parse_column_order_indices
    return nil if order.empty?

    valid_indices = (0...column_count.to_i).to_a
    order.select { |index| valid_indices.include?(index) }
  end

  def rows_for_processing(default_rows:)
    return default_rows if edited_rows_json.blank?

    parse_edited_rows!(column_count: Array(headers).size)
  end

  private

  def validate_processing_options
    validate_selected_columns
    validate_blank_column
    validate_output_encoding
    validate_column_labels
    validate_edited_rows
  end

  def validate_selected_columns
    CsvTool::CsvProcessor.new(headers: Array(headers), rows: []).process!(
      selected_columns: selected_column_indices
    )
  rescue CsvTool::Error => e
    errors.add(:selected_columns, e.user_message)
  end

  def validate_blank_column
    return if blank_column.blank?

    index = Integer(blank_column)
    return if (0...Array(headers).size).cover?(index)

    errors.add(:blank_column, CsvTool::ColumnNotFoundError.new.user_message)
  rescue ArgumentError, TypeError
    errors.add(:blank_column, CsvTool::ColumnNotFoundError.new.user_message)
  end

  def validate_output_encoding
    if output_encoding.blank?
      errors.add(:output_encoding, "出力文字コードを選択してください")
      return
    end

    return if CsvTool::SUPPORTED_OUTPUT_ENCODINGS.include?(output_encoding)

    errors.add(:output_encoding, "選択できない出力文字コードです")
  end

  def validate_column_labels
    return if errors[:selected_columns].present?

    selected_column_indices.each { |index| output_label_for(index) }
  rescue CsvTool::InvalidColumnLabelsError => e
    errors.add(:column_labels_json, e.user_message)
  end

  def output_label_for(index)
    labels = parsed_column_labels
    key = index.to_s
    return labels[key].to_s.strip if labels.key?(key)
    return labels[index].to_s.strip if labels.key?(index)

    Array(headers)[index].to_s.strip
  end

  def parsed_column_labels
    if column_labels_json.present?
      parse_column_labels_json!
    elsif column_labels.is_a?(Hash)
      column_labels.transform_keys(&:to_s)
    else
      {}
    end
  end

  def parse_column_labels_json!
    data = JSON.parse(column_labels_json.to_s)
    raise CsvTool::InvalidColumnLabelsError, "column labels is not a hash" unless data.is_a?(Hash)

    data.transform_keys(&:to_s).transform_values { |value| value.nil? ? "" : value.to_s }
  rescue JSON::ParserError
    raise CsvTool::InvalidColumnLabelsError, "invalid column labels json"
  end

  def validate_edited_rows
    return if edited_rows_json.blank?

    parse_edited_rows!(column_count: Array(headers).size)
  rescue CsvTool::InvalidEditedRowsError => e
    errors.add(:edited_rows_json, e.user_message)
  end

  def parse_edited_rows!(column_count:)
    data = JSON.parse(edited_rows_json.to_s)
    raise CsvTool::InvalidEditedRowsError, "edited rows is not an array" unless data.is_a?(Array)
    if data.empty?
      raise CsvTool::InvalidEditedRowsError, "no rows selected for output"
    end

    if row_count.present? && data.size > row_count.to_i
      raise CsvTool::InvalidEditedRowsError, "edited row count mismatch"
    end

    data.map do |row|
      normalize_edited_row(row, column_count: column_count)
    end
  rescue JSON::ParserError
    raise CsvTool::InvalidEditedRowsError, "invalid edited rows json"
  end

  def normalize_edited_row(row, column_count:)
    if row.is_a?(Array)
      column_count.times.map do |index|
        value = row[index]
        value.nil? ? nil : value.to_s
      end
    elsif row.is_a?(Hash)
      column_count.times.map do |index|
        value = row[index.to_s] || row[index]
        value.nil? ? nil : value.to_s
      end
    else
      raise CsvTool::InvalidEditedRowsError, "edited row is not an array or hash"
    end
  end

  def parse_column_order_indices
    return [] if column_order.blank?

    data = JSON.parse(column_order.to_s)
    return [] unless data.is_a?(Array)

    data.filter_map do |value|
      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  rescue JSON::ParserError
    []
  end
end
