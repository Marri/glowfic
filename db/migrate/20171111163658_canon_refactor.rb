class CanonRefactor < ActiveRecord::Migration[5.0]
  def up
    Tag.where(type: "Canon").each do |canon|
      # find or create a setting with the same name
      setting = Setting.where(name: canon.name.strip).first
      setting ||= Setting.create!(
        name: canon.name.strip,
        created_at: canon.created_at,
        updated_at: canon.updated_at,
        description: canon.description,
        owned: canon.owned,
        user: canon.user)

      # copy non-duplicate characters
      new_chars = canon.characters - setting.characters
      setting.characters << new_chars

      # update all non-loop Canon > Settings relationships to be Setting > Settings
      same_tag = Tag::SettingTag.where(tag_id: canon.id, tagged_id: setting.id).first
      same_tag.destroy! if same_tag.present?
      Tag::SettingTag.where(tag_id: canon.id).update_all(tag_id: setting.id)

      # death to the canon
      canon.destroy!
    end
  end

  def down
  end
end
