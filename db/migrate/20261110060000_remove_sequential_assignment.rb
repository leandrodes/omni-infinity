class RemoveSequentialAssignment < ActiveRecord::Migration[7.2]
  def up
    execute 'UPDATE assignment_policies SET assignment_order = 1 WHERE assignment_order = 2'
    execute 'UPDATE teams SET auto_assignment_algorithm = 1 WHERE auto_assignment_algorithm = 2'
  end

  def down; end
end
