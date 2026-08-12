# frozen_string_literal: true

module CsvTool
  class CsvEncodingDetector
    UTF8_BOM = "\xEF\xBB\xBF".b

    attr_reader :detected_encoding, :utf8_content

    def initialize(source)
      @binary_content = read_binary(source)
    end

    def detect!
      @detected_encoding = detect_encoding_name
      @utf8_content = build_utf8_content
      self
    end

    private

    attr_reader :binary_content

    def read_binary(source)
      case source
      when String
        source.dup.force_encoding(Encoding::ASCII_8BIT)
      when IO, ActionDispatch::Http::UploadedFile
        source.rewind if source.respond_to?(:rewind)
        content = source.read
        source.rewind if source.respond_to?(:rewind)
        content.b
      else
        raise ArgumentError, "unsupported source type: #{source.class}"
      end
    end

    def detect_encoding_name
      return "UTF-8-BOM" if utf8_bom?
      return "UTF-8" if utf8_valid?
      return "Windows-31J" if windows_31j_valid?

      raise EncodingDetectionError, "unable to detect encoding"
    end

    def utf8_bom?
      binary_content.start_with?(UTF8_BOM)
    end

    def bytes_without_bom
      utf8_bom? ? binary_content.byteslice(3..) : binary_content
    end

    def utf8_valid?
      bytes_without_bom.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end

    def windows_31j_valid?
      binary_content.dup.force_encoding(Encoding::Windows_31J).valid_encoding?
    end

    def build_utf8_content
      case detected_encoding
      when "UTF-8-BOM"
        bytes_without_bom.dup.force_encoding(Encoding::UTF_8)
      when "UTF-8"
        binary_content.dup.force_encoding(Encoding::UTF_8)
      when "Windows-31J"
        binary_content.dup.force_encoding(Encoding::Windows_31J).encode(Encoding::UTF_8)
      end
    end
  end
end
