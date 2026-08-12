# frozen_string_literal: true

require "json"
require "securerandom"

module CsvTool
  class CsvTempfileStore
    TOKEN_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    def initialize(base_dir: TEMP_DIR)
      @base_dir = Pathname(base_dir)
      FileUtils.mkdir_p(@base_dir)
    end

    def generate_token
      SecureRandom.uuid
    end

    def save_input!(token:, content:, original_filename:, detected_encoding:, **metadata)
      validate_token!(token)
      validate_original_filename!(original_filename)

      write_file(input_path(token), content)
      write_meta(
        token,
        metadata.merge(
          original_filename: original_filename,
          detected_encoding: detected_encoding,
          saved_at: Time.current.iso8601
        )
      )

      token
    end

    def read_input(token)
      read_file(input_path(token))
    end

    def save_output!(token:, content:)
      validate_token!(token)
      write_file(output_path(token), content)
    end

    def read_output(token)
      path = output_path(token)
      raise SessionExpiredError, "file not found: #{path.basename}" unless path.exist?

      path.binread
    end

    def read_meta(token)
      path = meta_path(token)
      raise SessionExpiredError, "meta file not found for token=#{token}" unless path.exist?

      JSON.parse(path.read, symbolize_names: true)
    end

    def delete!(token)
      validate_token!(token)

      [input_path(token), output_path(token), meta_path(token)].each do |path|
        File.delete(path) if path.exist?
      end

      true
    end

    def exists?(token)
      validate_token!(token)
      input_path(token).exist?
    end

    def input_path(token)
      path_for(token, "input.csv")
    end

    def output_path(token)
      path_for(token, "output.csv")
    end

    def meta_path(token)
      path_for(token, "meta.json")
    end

    private

    attr_reader :base_dir

    def path_for(token, suffix)
      validate_token!(token)
      base_dir.join("#{token}_#{suffix}")
    end

    def validate_token!(token)
      raise ArgumentError, "invalid token" unless token.to_s.match?(TOKEN_FORMAT)
    end

    def validate_original_filename!(original_filename)
      filename = original_filename.to_s
      if filename.blank? || filename.include?("/") || filename.include?("\\") || filename.include?("..")
        raise ArgumentError, "invalid original filename"
      end
    end

    def write_file(path, content)
      path.binwrite(content.to_s.b)
    end

    def read_file(path)
      raise SessionExpiredError, "file not found: #{path.basename}" unless path.exist?

      path.binread.force_encoding(Encoding::UTF_8)
    end

    def write_meta(token, metadata)
      path = meta_path(token)
      path.write(JSON.pretty_generate(metadata))
    end
  end
end
