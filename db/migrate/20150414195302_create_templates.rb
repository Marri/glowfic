class CreateTemplates < ActiveRecord::Migration
  def change
    create_table :templates do |t|
      t.integer :user_id, :null => false
      t.string :name
      t.timestamps null: true
    end
    add_index :templates, :user_id
  end
end
