# frozen_string_literal: true

class CsvFilesController < ApplicationController
  include CsvFilesHelper
  include PosthogTrackable

  rescue_from StandardError, with: :handle_unexpected_error
  rescue_from CsvTool::Error, with: :handle_csv_tool_error

  before_action :load_csv_upload, only: %i[preview run result download]

  def new
  end

  def create
    form = CsvUploadForm.new(upload_params)

    unless form.valid?
      track_posthog("csv_upload_failed", error_type: form.errors[:file].first)
      redirect_to new_csv_file_path, alert: form.errors[:file].first
      return
    end

    detector = CsvTool::CsvEncodingDetector.new(form.file).detect!
    read_result = CsvTool::CsvReader.new(detector.utf8_content).read!
    store = CsvTool::CsvTempfileStore.new
    delete_previous_upload!(store)

    token = store.generate_token
    store.save_input!(
      token: token,
      content: detector.utf8_content,
      original_filename: form.file.original_filename,
      detected_encoding: detector.detected_encoding,
      row_count: read_result.row_count,
      column_count: read_result.column_count,
      headers: read_result.headers,
      warnings: read_result.warnings
    )

    save_csv_tool_session!(
      token: token,
      original_filename: form.file.original_filename,
      detected_encoding: detector.detected_encoding,
      row_count: read_result.row_count,
      column_count: read_result.column_count,
      headers: read_result.headers
    )

    track_posthog(
      "csv_uploaded",
      row_count: read_result.row_count,
      column_count: read_result.column_count,
      detected_encoding: detector.detected_encoding,
      warning_count: read_result.warnings.size,
      file_extension: File.extname(form.file.original_filename.to_s).downcase
    )

    redirect_to preview_csv_file_path(token: token)
  end

  def preview
    assign_preview_data
    track_posthog(
      "preview_viewed",
      row_count: @row_count,
      column_count: @column_count,
      warning_count: @warnings.size
    )
  end

  def run
    form = CsvProcessingForm.new(
      processing_params.merge(
        headers: @csv_tool_session[:headers],
        row_count: @csv_tool_session[:row_count]
      )
    )

    unless form.valid?
      track_posthog(
        "csv_processing_failed",
        error_fields: form.errors.attribute_names.map(&:to_s)
      )
      redirect_to preview_csv_file_path(token: params[:token]), alert: form.errors.full_messages.first
      return
    end

    store = CsvTool::CsvTempfileStore.new
    read_result = CsvTool::CsvReader.new(store.read_input(params[:token])).read!
    rows = form.rows_for_processing(default_rows: read_result.rows)

    process_result = CsvTool::CsvProcessor.new(
      headers: read_result.headers,
      rows: rows
    ).process!(
      selected_columns: form.selected_column_indices,
      column_labels: form.column_labels_for_processor,
      column_order: form.column_order_for_processor(column_count: read_result.column_count),
      remove_empty_rows: form.remove_empty_rows?,
      blank_column: form.blank_column
    )

    write_result = CsvTool::CsvWriter.new(
      headers: process_result.headers,
      rows: process_result.rows
    ).write!(output_encoding: form.output_encoding)

    result = CsvTool::CsvProcessingResult.build(
      rows_before: read_result.row_count,
      process_result: process_result,
      write_result: write_result,
      output_encoding: form.output_encoding,
      original_filename: @csv_tool_session[:original_filename],
      reader_warnings: read_result.warnings
    )

    store.save_output!(token: params[:token], content: result.output_content)
    save_csv_tool_session!(@csv_tool_session.merge(result: result.to_session_hash))

    track_posthog(
      "csv_processed",
      rows_before: result.rows_before,
      rows_after: result.rows_after,
      rows_removed: result.rows_removed,
      columns_count: result.columns_count,
      output_encoding: result.output_encoding,
      remove_empty_rows: form.remove_empty_rows?,
      blank_column_used: form.blank_column.present?,
      selected_columns_count: form.selected_column_indices.size
    )

    redirect_to result_csv_file_path(token: params[:token])
  end

  def result
    return unless load_processing_result_data

    track_posthog(
      "result_viewed",
      rows_after: @result[:rows_after],
      columns_count: @result[:columns_count],
      output_encoding: @result[:output_encoding]
    )
  end

  def download
    return unless load_processing_result_data

    track_posthog(
      "csv_downloaded",
      rows_after: @result[:rows_after],
      columns_count: @result[:columns_count],
      output_encoding: @result[:output_encoding]
    )

    store = CsvTool::CsvTempfileStore.new
    content = store.read_output(params[:token])

    send_data content,
              filename: csv_converted_filename(@original_filename),
              type: csv_download_content_type(@result[:output_encoding]),
              disposition: "attachment"
  end

  private

  def upload_params
    params.fetch(:csv_upload_form, {}).permit(:file)
  end

  def processing_params
    params.fetch(:csv_processing_form, {}).permit(
      :remove_empty_rows, :blank_column, :output_encoding, :edited_rows_json, :column_order,
      :column_labels_json,
      selected_columns: []
    )
  end

  def load_csv_upload
    @csv_tool_session = csv_tool_session

    unless valid_session_token?
      redirect_to new_csv_file_path, alert: CsvTool::SessionExpiredError.new.user_message
      return
    end

    ensure_upload_exists!
  end

  def valid_session_token?
    token = params[:token].to_s
    @csv_tool_session.present? &&
      @csv_tool_session[:token] == token &&
      token.match?(CsvTool::CsvTempfileStore::TOKEN_FORMAT)
  end

  def ensure_upload_exists!
    return if CsvTool::CsvTempfileStore.new.exists?(params[:token])

    redirect_to new_csv_file_path, alert: CsvTool::SessionExpiredError.new.user_message
  end

  def csv_tool_session
    session[:csv_tool]&.with_indifferent_access
  end

  def save_csv_tool_session!(attributes)
    session[:csv_tool] = attributes
  end

  def delete_previous_upload!(store)
    token = csv_tool_session&.dig(:token)
    return if token.blank?

    store.delete!(token)
  rescue ArgumentError
    nil
  end

  def assign_preview_data
    store = CsvTool::CsvTempfileStore.new
    meta = store.read_meta(params[:token])
    read_result = CsvTool::CsvReader.new(store.read_input(params[:token])).read!

    @original_filename = meta[:original_filename]
    @detected_encoding = meta[:detected_encoding]
    @row_count = read_result.row_count
    @column_count = read_result.column_count
    @headers = read_result.headers
    @rows = read_result.rows
    @warnings = read_result.warnings
  end

  def load_processing_result_data
    @result = @csv_tool_session[:result]

    if @result.blank?
      redirect_to preview_csv_file_path(token: params[:token]),
                  alert: "加工結果がありません。加工を実行してください。"
      return false
    end

    @result = @result.with_indifferent_access
    @original_filename = @csv_tool_session[:original_filename]
    true
  end

  def handle_csv_tool_error(error)
    log_csv_tool_error(error)
    redirect_with_csv_tool_alert(error.user_message)
  end

  def handle_unexpected_error(error)
    unexpected = CsvTool::UnexpectedError.new(error)
    log_csv_tool_error(unexpected, cause: error)
    redirect_with_csv_tool_alert(unexpected.user_message)
  end

  def log_csv_tool_error(error, cause: nil)
    token = params[:token].presence || csv_tool_session&.dig(:token)
    Rails.logger.error(
      "[CsvTool] action=#{action_name} token=#{token} error=#{error.class}: #{error.message}"
    )
    return unless cause

    Rails.logger.error("[CsvTool] cause=#{cause.class}: #{cause.message}")
    Rails.logger.error(cause.backtrace&.first(10)&.join("\n"))
  end

  def redirect_with_csv_tool_alert(message)
    case action_name
    when "create", "preview"
      redirect_to new_csv_file_path, alert: message
    when "run"
      redirect_to preview_csv_file_path(token: params[:token]), alert: message
    when "download"
      redirect_to result_csv_file_path(token: params[:token]), alert: message
    else
      redirect_to new_csv_file_path, alert: message
    end
  end
end
