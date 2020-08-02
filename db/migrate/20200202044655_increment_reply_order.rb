class IncrementReplyOrder < ActiveRecord::Migration[5.2]
  def change
    Reply.update_all('reply_order = reply_order + 1')
  end
end
