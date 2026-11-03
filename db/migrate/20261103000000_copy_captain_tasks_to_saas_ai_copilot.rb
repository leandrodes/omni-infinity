class CopyCaptainTasksToSaasAiCopilot < ActiveRecord::Migration[7.2]
  def up
    Account.find_each do |account|
      next unless account.feature_enabled?('captain_tasks')
      next if account.feature_enabled?('saas_ai_copilot')

      account.enable_features!('saas_ai_copilot')
    end
  end

  def down
    # Data migration cannot be safely reversed.
  end
end
