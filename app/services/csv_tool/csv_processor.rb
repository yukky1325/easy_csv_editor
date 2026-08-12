# frozen_string_literal: true

module CsvTool
  class CsvProcessor
    ProcessResult = Struct.new(:headers, :rows, keyword_init: true)

    def initialize(headers:, rows:)
      @headers = Array(headers)
      @rows = rows
    end

    def process!(selected_columns:, remove_empty_rows: false, blank_column: nil, column_labels: {},
                 column_order: nil)
      normalized_indices = normalize_selected_indices(selected_columns)
      validate_selected_indices!(normalized_indices)
      validate_blank_column!(blank_column)

      selected_indices = order_selected_indices(normalized_indices, column_order)
      output_headers = selected_indices.map { |index| resolve_output_header(index, column_labels) }

      working_rows = rows
      working_rows = reject_completely_empty_rows(working_rows) if remove_empty_rows

      if blank_column.present?
        blank_index = parse_column_index(blank_column)
        working_rows = reject_blank_column_rows(working_rows, blank_index)
      end

      processed_rows = working_rows.map do |row|
        selected_indices.map { |index| row_value(row, index) }
      end

      ProcessResult.new(headers: output_headers, rows: processed_rows)
    end

    private

    attr_reader :headers, :rows

    def normalize_selected_indices(selected_columns)
      Array(selected_columns).filter_map do |value|
        next if value.blank?

        parse_column_index(value)
      end
    end

    def parse_column_index(value)
      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

    def validate_selected_indices!(selected_indices)
      raise NoColumnsSelectedError, "no columns selected" if selected_indices.empty?

      unknown_indices = selected_indices - valid_column_indices
      return if unknown_indices.empty?

      raise ColumnNotFoundError, "unknown columns: #{unknown_indices.join(', ')}"
    end

    def validate_blank_column!(blank_column)
      return if blank_column.blank?

      index = parse_column_index(blank_column)
      return if index && valid_column_indices.include?(index)

      raise ColumnNotFoundError, "blank column not found: #{blank_column}"
    end

    def valid_column_indices
      (0...headers.size).to_a
    end

    def reject_completely_empty_rows(rows)
      rows.reject { |row| row_completely_empty?(row) }
    end

    def row_completely_empty?(row)
      headers.each_index.all? { |index| blank_cell?(row_value(row, index)) }
    end

    def reject_blank_column_rows(rows, blank_index)
      rows.reject { |row| blank_cell?(row_value(row, blank_index)) }
    end

    def blank_cell?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def resolve_output_header(index, column_labels)
      labels = column_labels.is_a?(Hash) ? column_labels : {}
      key = index.to_s
      return labels[key].to_s.strip if labels.key?(key)
      return labels[index].to_s.strip if labels.key?(index)

      headers[index].to_s.strip
    end

    def order_selected_indices(normalized_indices, column_order)
      if column_order.present?
        Array(column_order).filter_map { |value| parse_column_index(value) }
                           .select { |index| normalized_indices.include?(index) }
      else
        valid_column_indices.select { |index| normalized_indices.include?(index) }
      end
    end

    def row_value(row, index)
      return row[index] if row.is_a?(Array)

      row[index] || row[index.to_s]
    end
  end
end
