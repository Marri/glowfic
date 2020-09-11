class CreatePostLinks < ActiveRecord::Migration[5.2]
  def change
    create_table :post_links do |t|
      t.integer :linking_post_id, null: false
      t.integer :linked_post_id, null: false
      t.text :relationship, null: false, default: "related to"
      t.boolean :approved, default: false
      t.timestamps
    end

    add_index :post_links, :linking_post_id
    add_index :post_links, :linked_post_id
  end
end
