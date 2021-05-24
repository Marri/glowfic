class MigrateTags < ActiveRecord::Migration[5.2]
  def up
    add_column :tags, :new_id, :integer

    batch_size = 1000
    times = (Tag.count.to_f / batch_size).ceil
    times.times do |step|
      settings = connection.exec_query(
        <<~SQL
          SELECT tags.*
          FROM tags
          WHERE tags.type = 'Setting'
          ORDER BY tags.id ASC
          OFFSET #{step * batch_size}
          LIMIT #{batch_size}
        SQL
      )

      settings.rows.each do |row|
        id, user_id, name, created_at, updated_at, _type, description, owned = row
        new = Setting.create!(
          user_id: user_id,
          name: name,
          description: description,
          owned: owned,
          created_at: created_at,
          updated_at: updated_at,
        )
        connection.exec_update(
          <<~SQL
            UPDATE tags
            SET new_id = #{new.id}
            WHERE id = #{id}
          SQL
        )
      end
    end

    CharacterTag.joins(:tag).where("tags.type = 'Setting'").in_batches do |batch|
      char_tags = batch.pluck('tags.new_id', :character_id)
      char_tags.each do |setting_id, character_id|
        Setting::Character.create!(setting_id: setting_id, character_id: character_id)
      end
    end

    PostTag.joins(:tag).where("tags.type = 'Setting'").in_batches do |batch|
      post_tags = batch.pluck('tags.new_id', :post_id)
      post_tags.each do |setting_id, post_id|
        Setting::Post.create!(setting_id: setting_id, post_id: post_id)
      end
    end

    tag_tags = Tag::SettingTag.joins('INNER JOIN tags t1 ON t1.id = tag_tags.tag_id').joins('INNER JOIN tags t2 ON t2.id = tag_tags.tagged_id')
    tag_tags.in_batches do |batch|
      batch = batch.pluck('t1.new_id', 't2.new_id')
      batch.each do |tag_id, tagged_id|
        Setting::SettingTag.create!(tag_id: tag_id, tagged_id: tagged_id)
      end
    end
    remove_column :tags, :new_id
  end

  def down
    Setting.delete_all
    Setting::Character.delete_all
    Setting::Post.delete_all
    Setting::SettingTag.delete_all
  end
end
