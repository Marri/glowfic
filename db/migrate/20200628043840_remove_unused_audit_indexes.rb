class RemoveUnusedAuditIndexes < ActiveRecord::Migration[5.2]
  def change
    remove_index :audits, name: 'index_audits_on_created_at'
    remove_index :audits, name: 'index_audits_on_request_uuid'
    remove_index :audits, name: 'user_index'
  end
end
