class AddTranscribeAudioToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :inboxes, :transcribe_audio, :boolean, default: true, null: false
  end
end
