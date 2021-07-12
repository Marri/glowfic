module Permissible
  extend ActiveSupport::Concern

  MOD_PERMS = [
    :edit_posts,
    :edit_replies,
    :edit_characters,
    :import_posts,
    # :edit_tags,
    # :delete_tags,
    # :edit_continuities
  ]

  included do
    enum role_id: {
      admin: 1,
      mod: 2,
      importer: 3,
      suspended: 4
    }

    def has_permission?(permission)
      return false unless role_id
      return true if admin?
      return true if importer? && permission == :import_posts
      return false unless mod?
      MOD_PERMS.include?(permission)
    end
  end
end
