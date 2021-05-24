class DeleteSettingTags < ActiveRecord::Migration[5.2]
  def up
    connection.exec_delete(
      <<~SQL
        DELETE FROM tags
        WHERE tags.type = 'Setting'
      SQL
    )
  end

  def down
    #raise ActiveRecord::IrreversibleMigration
  end
end
