class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Desativado no Omni-Channel Infinity: NÃO consultamos versões nem enviamos
    # dados para o hub do Chatwoot. As atualizações são aplicadas manualmente
    # pelo responsável e não exibimos aviso de "atualização disponível".
    nil
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
