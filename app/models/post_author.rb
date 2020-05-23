class PostAuthor < ApplicationRecord
  belongs_to :post, optional: false
  belongs_to :user, optional: false

  validates :user, uniqueness: { scope: :post }

  def opt_out_of_owed
    change_owed { joined? ? self.update(can_owe: false) : self.destroy } # rubocop:disable Rails/SaveBang
  end

  def opt_in_to_owed
    change_owed { can_owe? ? true : self.update(can_owe: true) } # rubocop:disable Rails/SaveBang
  end

  private

  def change_owed
    success = yield
    post.errors.merge(errors) unless success
    success
  end
end
