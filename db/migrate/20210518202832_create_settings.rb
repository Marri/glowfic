class CreateSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :settings do |t|
      t.citext :name, null: false, index: true
      t.integer :user_id, null: false
      t.boolean :owned, default: false
      t.text :description
      t.timestamps
    end

    create_table :setting_characters do |t|
      t.integer :character_id, null: false, index: true
      t.integer :setting_id, null: false, index: true
      t.timestamps
    end

    create_table :setting_posts do |t|
      t.integer :post_id, null: false, index: true
      t.integer :setting_id, null: false, index: true
      t.timestamps
    end

    create_table :setting_tags do |t|
      t.integer :tagged_id, null: false, index: true
      t.integer :tag_id, null: false, index: true
      t.timestamps
    end
  end
end
