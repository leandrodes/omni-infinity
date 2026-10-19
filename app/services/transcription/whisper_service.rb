require 'httparty'
require 'fileutils'

# Transcreve anexos de áudio usando o provedor configurado pela conta:
#
#   - :whisper_asr -> serviço Whisper auto-hospedado
#     (compatível com https://github.com/ahmetoner/whisper-asr-webservice)
#   - :openai      -> API compatível com OpenAI/Groq (/audio/transcriptions)
#
# Grava o resultado em `attachment.meta['transcribed_text']`, que o front-end já
# sabe exibir abaixo do player de áudio e que também é usado pelo LLM
# (`Message#content_for_llm`).
module Transcription
  class WhisperService
    # Limite de 25 MB (decimal) do endpoint de transcrição.
    BYTE_LIMIT = 25_000_000
    READ_TIMEOUT = 600

    attr_reader :attachment

    def initialize(attachment)
      @attachment = attachment
    end

    def perform
      return { error: 'orphan_attachment' } if attachment.message.blank?
      return { error: 'no_file' } unless attachment.file.attached?

      @provider = Transcription::Config.provider_for(attachment.message.inbox&.account)
      return { error: 'not_configured' } if @provider.blank?

      blob = attachment.file.blob
      return { error: 'too_large' } if blob.byte_size.to_i > BYTE_LIMIT

      existing = attachment.meta&.[]('transcribed_text')
      return { success: true, text: existing } if existing.present?

      text = transcribe(blob)
      return { error: 'empty_transcription' } if text.blank?

      store(text)
      { success: true, text: text }
    rescue StandardError => e
      Rails.logger.warn("[transcription] attachment=#{attachment&.id} #{e.class}: #{e.message}")
      { error: e.message }
    end

    private

    def transcribe(blob)
      path = download(blob)
      response = call_endpoint(path)
      extract_text(response)
    ensure
      FileUtils.rm_f(path) if path.present?
    end

    def download(blob)
      dir = Rails.root.join('tmp/uploads/audio-transcriptions')
      FileUtils.mkdir_p(dir)
      extension = blob.filename.extension.presence || extension_for(blob.content_type)
      path = File.join(dir, "#{blob.key}-#{SecureRandom.hex(4)}.#{extension}")
      File.open(path, 'wb') { |file| blob.open { |blob_file| IO.copy_stream(blob_file, file) } }
      path
    end

    def extension_for(content_type)
      subtype = content_type.to_s.downcase.split(';').first.to_s.split('/').last.to_s.presence
      { 'x-m4a' => 'm4a', 'x-wav' => 'wav', 'x-mp3' => 'mp3', 'ogg' => 'oga' }.fetch(subtype, subtype || 'oga')
    end

    def call_endpoint(path)
      response = if openai_provider?
                   call_openai(path)
                 else
                   call_whisper_asr(path)
                 end

      raise "transcription endpoint returned #{response.code}: #{response.body.to_s.first(200)}" unless response.success?

      response.parsed_response
    end

    def call_openai(path)
      HTTParty.post(
        openai_url,
        headers: auth_headers,
        multipart: true,
        body: openai_body(path),
        timeout: READ_TIMEOUT
      )
    end

    def call_whisper_asr(path)
      HTTParty.post(
        whisper_asr_url,
        query: whisper_asr_query,
        headers: auth_headers,
        multipart: true,
        body: { audio_file: File.new(path, 'rb') },
        timeout: READ_TIMEOUT
      )
    end

    def openai_provider?
      @provider[:kind] == Transcription::Config::OPENAI
    end

    def openai_url
      base = @provider[:endpoint]
      return base if base.end_with?('/audio/transcriptions')

      "#{base}/audio/transcriptions"
    end

    def openai_body(path)
      body = { file: File.new(path, 'rb'), model: @provider[:model].presence || 'whisper-1' }
      body[:language] = @provider[:language] if @provider[:language].present?
      body
    end

    def whisper_asr_url
      base = @provider[:endpoint]
      return base if base.end_with?('/asr')

      "#{base}/asr"
    end

    def whisper_asr_query
      params = { task: 'transcribe', output: 'json', encode: 'true' }
      params[:language] = @provider[:language] if @provider[:language].present?
      params
    end

    def auth_headers
      key = @provider[:api_key].to_s
      key.present? ? { 'Authorization' => "Bearer #{key}" } : {}
    end

    def store(text)
      attachment.update!(meta: (attachment.meta || {}).merge('transcribed_text' => text))
      message = attachment.message
      return if message.blank?

      message.reload.send_update_event
      message.reindex if ChatwootApp.advanced_search_allowed?
    end

    def extract_text(parsed)
      parsed = parse_if_json(parsed)
      return parsed['text'].to_s.strip if parsed.is_a?(Hash) && parsed['text'].present?

      if parsed.is_a?(Hash) && parsed['segments'].is_a?(Array)
        joined = parsed['segments'].filter_map { |segment| segment['text'] }.join(' ').strip
        return joined if joined.present?
      end

      parsed.to_s.strip
    end

    def parse_if_json(value)
      return value unless value.is_a?(String)
      return value unless value.lstrip.start_with?('{', '[')

      JSON.parse(value)
    rescue JSON::ParserError
      value
    end
  end
end
