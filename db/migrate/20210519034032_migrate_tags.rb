class MigrateTags < ActiveRecord::Migration[5.2]
  def up
    #settings = Tag.where("tags.type = 'Setting'").ordered_by_id
    settings = connection.exec_query(
      <<~SQL
        SELECT tags.*
        FROM tags
        WHERE tags.type = 'Setting'
        ORDER BY tags.id ASC
      SQL
    )

    settings.rows.each do |row|
      _id, user_id, name, created_at, updated_at, _type, description, owned = row
      Setting.create!(
        user_id: user_id,
        name: name,
        description: description,
        owned: owned,
        created_at: created_at,
        updated_at: updated_at,
      )
    end

    char_tags = CharacterTag.joins(:tag).where("tags.type = 'Setting'").order(id: :asc).pluck('tags.name', :character_id)
    char_tags.each do |name, character_id|
      setting = Setting.find_by(name: name)
      Setting::Character.create!(setting: setting, character_id: character_id)
    end

    post_tags = PostTag.joins(:tag).where("tags.type = 'Setting'").order(id: :asc).pluck('tags.name', :post_id)
    post_tags.each do |name, post_id|
      setting = Setting.find_by(name: name)
      Setting::Post.create!(setting: setting, post_id: post_id)
    end

    tag_tags = Tag::SettingTag
      .joins('INNER JOIN tags t1 ON t1.id = tag_tags.tag_id')
      .joins('INNER JOIN tags t2 ON t2.id = tag_tags.tagged_id')
      .pluck('t1.name', 't2.name')
    tag_tags.each do |tag_name, tagged_name|
      tag = Setting.find_by(name: tag_name)
      tagged = Setting.find_by(name: tagged_name)
      Setting::SettingTag.create!(tag_id: tag.id, tagged_id: tagged.id)
    end
  end

  def down
    Setting.delete_all
    Setting::Character.delete_all
    Setting::Post.delete_all
    Setting::Setting_Tag.delete_all
  end
end
