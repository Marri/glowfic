class AddRepliesOwedIndicatorToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :replies_owed_indicator, :boolean, default: false
  end
end
