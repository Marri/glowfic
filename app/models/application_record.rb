class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def audited_user_id
    user = ::Audited.store[:audited_user] # from as_user
    user ||= ::Audited.store[:current_user].call if ::Audited.store[:current_user].respond_to?(:call) # from controller method
    return nil if user.nil? && !Rails.env.test? # for debugging purposes this should fail loudly in tests
    user.id
  end
end
