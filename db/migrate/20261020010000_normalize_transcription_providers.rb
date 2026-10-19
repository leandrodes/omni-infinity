class NormalizeTranscriptionProviders < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:transcription_settings)

    execute "UPDATE transcription_settings SET provider = 'external' WHERE provider IN ('openai', 'whisper')"
  end

  def down
    # no-op: valores normalizados para 'external'
  end
end
