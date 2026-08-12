# frozen_string_literal: true

module CsvTool
  class TempfileCleaner
    def initialize(base_dir: TEMP_DIR, ttl: TEMP_FILE_TTL, now: Time.current)
      @base_dir = Pathname(base_dir)
      @ttl = ttl
      @now = now
    end

    def cleanup!
      return 0 unless base_dir.directory?

      deleted = 0
      base_dir.children.each do |path|
        next unless path.file?
        next if path.mtime > cutoff_time

        File.delete(path)
        deleted += 1
      end

      deleted
    end

    private

    attr_reader :base_dir, :ttl, :now

    def cutoff_time
      now - ttl
    end
  end
end
