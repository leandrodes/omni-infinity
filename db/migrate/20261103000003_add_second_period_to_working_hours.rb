class AddSecondPeriodToWorkingHours < ActiveRecord::Migration[7.2]
  def change
    change_table :working_hours, bulk: true do |t|
      t.boolean :second_period_enabled, null: false, default: false
      t.integer :second_open_hour
      t.integer :second_open_minutes
      t.integer :second_close_hour
      t.integer :second_close_minutes
    end
  end
end
