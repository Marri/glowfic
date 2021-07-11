class CreateNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :notifications do |t|
      t.integer :user_id, null: false
      t.integer :post_id, null: true
      t.boolean :unread, null: false, default: true
      t.integer :notification_type, null: false
      t.text :error_msg, null: true
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, :user_id
  end
end
