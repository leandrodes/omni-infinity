# frozen_string_literal: true

# omni-infinity: atalho para o Bot Builder (baseado em chatwoot-addons, MIT).
# Atalho flutuante para o Bot Builder (/bot-builder). Injetado no shell HTML do
# dashboard apenas para usuários autenticados. Autocontido e à prova de falhas:
# qualquer erro na injeção devolve a página original intacta.
class BotBuilderNavMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    content_type = headers['Content-Type'] || headers['content-type'] || ''
    return [status, headers, response] unless content_type.include?('text/html')

    path = env['PATH_INFO'] || ''
    return [status, headers, response] if path.start_with?('/bot-builder')

    user = env['warden']&.user
    return [status, headers, response] unless user.is_a?(User)

    parts = []
    response.each { |part| parts << part }
    response.close if response.respond_to?(:close)
    body = parts.join

    if body.include?('</body>')
      body = body.sub('</body>', "#{button_html}</body>")
      headers['Content-Length'] = body.bytesize.to_s if headers['Content-Length']
    end

    [status, headers, [body]]
  rescue StandardError => e
    Rails.logger.warn("[bot-builder-nav] #{e.class}: #{e.message}")
    [status, headers, response]
  end

  private

  def button_html
    <<~'HTML'
      <a href="/bot-builder" title="Chatbot / Flow Builder"
         style="position:fixed;right:18px;bottom:18px;z-index:99998;display:inline-flex;align-items:center;gap:8px;background:#6366F1;color:#fff;padding:10px 16px;border-radius:9999px;font-family:Inter,system-ui,sans-serif;font-size:13px;font-weight:600;text-decoration:none;box-shadow:0 6px 20px rgba(99,102,241,.35)">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a2 2 0 0 1 2 2c0 .74-.4 1.39-1 1.73V7h1a7 7 0 0 1 7 7h1a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1h-1.07A7.001 7.001 0 0 1 7.07 19H6a1 1 0 0 1-1-1v-3a1 1 0 0 1 1-1h1a7 7 0 0 1 7-7h1V5.73c-.6-.34-1-.99-1-1.73a2 2 0 0 1 2-2zM9.5 16a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zm5 0a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z"/></svg>
        Chatbot
      </a>
    HTML
  end
end

Rails.application.config.middleware.insert_before BotBuilderMiddleware, BotBuilderNavMiddleware
