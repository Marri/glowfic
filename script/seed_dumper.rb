EXCLUDED_SCHEMA = {
  Icon: ['created_at', 'updated_at', 'has_gallery', 's3_key', 'credit'],
  Template: ['created_at', 'updated_at', 'description'],
  Character: ['created_at', 'updated_at', 'character_group_id', 'description'],
  CharacterAlias: ['created_at', 'updated_at'],
  Gallery: ['created_at', 'updated_at'],
  CharactersGallery: ['created_at', 'updated_at'],
  GalleriesIcon: ['created_at', 'updated_at'],
  Post: ['privacy', 'last_reply_id', 'last_user_id'],
  Reply: ['reply_order', 'thread_id'],
  ContentWarning: ['created_at', 'updated_at', 'description'],
  GalleryGroup: ['created_at', 'updated_at', 'description'],
  Setting: ['created_at', 'updated_at', 'description'],
  CharacterTag: ['created_at', 'updated_at'],
  GalleryTag: ['created_at', 'updated_at'],
  Tag::SettingTag => ['created_at', 'updated_at', 'suggested'],
  PostTag: ['created_at', 'updated_at', 'suggested'],
  'Audited::Audit': [],
  Post::Author => ['created_at', 'updated_at'],
  Message: ['created_at', 'updated_at'],
  Post::View => ['created_at', 'updated_at', 'ignored', 'notify_message', 'notify_email', 'warnings_hidden'],
}

MODELS = [Icon, Template, Character, CharacterAlias, Gallery, CharactersGallery, GalleriesIcon, Post, Reply, ContentWarning, GalleryGroup,
          Setting, CharacterTag, GalleryTag, Tag::SettingTag, PostTag, Post::View]

FILES = {
  # Icon: [Icon],
  Character: [Template, 'puts "Creating characters..."', Character, 'puts "Creating character aliases..."', CharacterAlias],
  Gallery: [Gallery, 'puts "Assigning galleries to characters..."', CharactersGallery, 'puts "Populating galleries with icons..."', GalleriesIcon],
  Post: [Post, 'puts "Setting up post views..."', Post::View, 'puts "Queuing flat post generation (will not update until jobs are run)"',
         'FlatPost.regenerate_all'],
  # Reply: [Reply],
  Tag: [ContentWarning, GalleryGroup, Setting, 'puts "Assigning tags to characters..."', CharacterTag, 'puts "Assigning tags to galleries..."',
        GalleryTag, 'puts "Attaching settings to each other..."', Tag::SettingTag, 'puts "Attaching tags to posts..."', PostTag]
}

def dump(model)
  puts "Dumping #{model.name.titleize.pluralize(model.count)}..."
  exclude = EXCLUDED_SCHEMA[model.name.to_sym].join(',')
  file = Rails.root.join('db', 'seeds', "#{model.name.demodulize.underscore}.rb")
  `rake db:seed:dump MODEL=#{model.name} EXCLUDE=#{exclude} FILE=#{file}`
  file
end

def sort(file)
  size = `wc -l < #{file}`.chomp.to_i
  `head -n 1 #{file} > db/seeds/tmp`
  `sed -n '2,#{size - 1}p' #{file} | sort -V >> db/seeds/tmp`
  `tail -n 1 #{file} >> db/seeds/tmp`
  `mv -f db/seeds/tmp #{file}`
end

def clean(file, expand=false)
  sort(file)
  lines = []
  File.readlines(file).each do |line|
    line.gsub!(/}$/, "},")
    line.gsub!(/{id: [0-9]{1,3},/, "{")

    line.gsub!(", nickname: nil", "")
    line.gsub!(", screenname: nil", "")
    line.gsub!(", template_id: nil", "")
    line.gsub!(", default_icon_id: nil", "")
    line.gsub!(", pb: nil", "")
    line.gsub!(", added_by_group: false", "")
    line.gsub!(", section_order: 0}", "}")
    line.gsub!(", owned: false", "")
    line.gsub!(", section_id: nil", "")
    line.gsub!(", character_id: nil", "")
    line.gsub!(", character_alias_id: nil", "")
    line.gsub!(", icon_id: nil", "")
    line.gsub!(", description: \"\"", "")
    line.gsub!(", description: nil", "")
    if expand
      line.gsub!("}", ",}")
      line.gsub!("{", "{\n   ")
      line.gsub!(/([\d"]),(?!\})/, "\\1,\n   ")
      line.gsub!("}", "\n  }")
    else
      line.gsub!("}", " }")
    end
    line.chomp!
    lines << line
  end
  File.open(file, 'w') do |f|
    lines.each do |line|
      f.puts(line)
    end
  end
end

MODELS.each do |model|
  next if model.count == 0
  puts "#{model.count} #{model.name.titleize.pluralize(model.count)}"
  file = dump(model)
  expand = true if [Character, Post, Reply, Audited::Audit].include?(model)
  clean(file, expand)
end

FILES.each do |key, value|
  file = Rails.root.join('db', 'seeds', "#{key.to_s.downcase}.out")
  value.each do |part|
    if part.is_a?(String)
      File.open(file, 'a') do |f|
        f.puts ""
        f.puts part
      end
    else
      part_file = Rails.root.join('db', 'seeds', "#{part.name.demodulize.underscore}.rb")
      next unless part_file.exist?
      `cat #{part_file} >> #{file}`
      `rm #{part_file}`
    end
  end
  `mv #{file} #{Rails.root.join('db', 'seeds', "#{key.to_s.downcase}.rb")}`
end
