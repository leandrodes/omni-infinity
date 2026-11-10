class NormalizeTeamAssignmentAlgorithms < ActiveRecord::Migration[7.2]
  def up
    execute 'UPDATE teams SET auto_assignment_algorithm = 0 WHERE auto_assignment_algorithm = 1'
    execute 'UPDATE teams SET auto_assignment_algorithm = 1 WHERE auto_assignment_algorithm = 2'
  end

  def down
    execute 'UPDATE teams SET auto_assignment_algorithm = 2 WHERE auto_assignment_algorithm = 1'
  end
end
