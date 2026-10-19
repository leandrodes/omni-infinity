class CreateTranscriptionSettings < ActiveRecord::Migration[7.2]
  def up
    create_table :transcription_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false, default: 'system'
      t.string :endpoint
      t.string :model
      t.string :language
      t.text :api_key
      t.timestamps
    end

    add_column :accounts, :transcription_allow_system, :boolean, null: false, default: false
    add_index :accounts, :transcription_allow_system

    # Preserva o comportamento atual das contas existentes: libera o Whisper
    # interno (gerenciado) e mantém a transcrição ligada até o cliente decidir.
    # Contas novas começam desligadas (transcription_allow_system = false).
    Account.reset_column_information
    Account.find_each do |account|
      settings = account.settings || {}
      settings['audio_transcriptions'] = true if settings['audio_transcriptions'].nil?
      account.update_columns(transcription_allow_system: true, settings: settings)
    end
  end

  def down
    remove_column :accounts, :transcription_allow_system
    drop_table :transcription_settings
  end
end
