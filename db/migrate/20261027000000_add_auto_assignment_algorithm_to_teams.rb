class AddAutoAssignmentAlgorithmToTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :auto_assignment_algorithm, :integer, default: 0, null: false
    add_column :team_members, :priority_level, :integer, default: 1, null: false
  end
end
