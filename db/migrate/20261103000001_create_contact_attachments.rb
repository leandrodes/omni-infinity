class CreateContactAttachments < ActiveRecord::Migration[7.2]
  def change
    create_table :contact_attachments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true

      t.timestamps
    end
  end
end
