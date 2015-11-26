class CreateIcons < ActiveRecord::Migration
  def up
    create_table :icons do |t|
      t.integer :user_id, :null => false
      t.string :url, :null => false
      t.string :keyword, :null => false
      t.timestamps
    end
    add_index :icons, :user_id
    add_index :icons, :keyword
  end

  def down
    drop_table :icons
  end
end
