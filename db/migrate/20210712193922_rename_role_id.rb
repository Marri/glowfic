class RenameRoleId < ActiveRecord::Migration[5.2]
  def change
    rename_column :users, :role_id, :role
  end
end
