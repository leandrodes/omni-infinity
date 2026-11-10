class AddAssignmentLevelsAndNormalizeOrders < ActiveRecord::Migration[7.2]
  def up
    add_column :inbox_members, :priority_level, :integer, null: false, default: 1

    # Existing round_robin (0) and balanced (1) policies both become balanced (0).
    execute 'UPDATE assignment_policies SET assignment_order = 0 WHERE assignment_order <> 0'
  end

  def down
    remove_column :inbox_members, :priority_level, :integer
  end
end
