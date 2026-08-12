# frozen_string_literal: true

module CsvTool
  class Error < StandardError
    class << self
      attr_reader :user_message_template

      def user_message_template=(message)
        @user_message_template = message.freeze
      end
    end

    def user_message
      self.class.user_message_template
    end
  end

  class FileNotSelectedError < Error
    self.user_message_template = "ファイルが選択されていません"
  end

  class InvalidExtensionError < Error
    self.user_message_template = "CSVファイル（.csv）を選択してください"
  end

  class FileSizeExceededError < Error
    def user_message
      limit = "#{(CsvTool::MAX_FILE_SIZE / 1.megabyte).round}MB"
      "ファイルサイズが上限（#{limit}）を超えています"
    end
  end

  class InvalidCsvError < Error
    self.user_message_template = "CSV形式が正しくありません"
  end

  class NoHeaderError < Error
    self.user_message_template = "ヘッダー行が見つかりません"
  end

  class EncodingDetectionError < Error
    self.user_message_template = "文字コードを判定できませんでした"
  end

  class EncodingConversionError < Error
    self.user_message_template = "文字コードの変換に失敗しました"
  end

  class ColumnNotFoundError < Error
    self.user_message_template = "指定された列が CSV に存在しません"
  end

  class NoColumnsSelectedError < Error
    self.user_message_template = "出力する列を 1 つ以上選択してください"
  end

  class EmptyResultError < Error
    self.user_message_template = "加工後のデータが 0 件です"
  end

  class InvalidEditedRowsError < Error
    self.user_message_template = "データの編集内容が正しくありません"
  end

  class InvalidColumnLabelsError < Error
    self.user_message_template = "列名の編集内容が正しくありません"
  end

  class SessionExpiredError < Error
    self.user_message_template = "セッションが切れました。最初からやり直してください"
  end

  class UnexpectedError < Error
    self.user_message_template = "予期しないエラーが発生しました"

    attr_reader :cause_exception

    def initialize(cause = nil)
      @cause_exception = cause
      super(build_internal_message(cause))
    end

    private

    def build_internal_message(cause)
      return "unexpected error" if cause.nil?

      "#{cause.class}: #{cause.message}"
    end
  end
end
