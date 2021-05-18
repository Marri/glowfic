ContentWarning.create!([
  { user_id: 5, name: "warning 1", type: "ContentWarning" },
  { user_id: 5, name: "warning 2", type: "ContentWarning" },
  { user_id: 5, name: "warning 3", type: "ContentWarning" },
])
GalleryGroup.create!([
  { user_id: 3, name: "JokerSherlock (SS)", type: "GalleryGroup" },
])

puts "Creating settings..."
Setting.create!([
  { user_id: 3, name: "Earth" },
  { user_id: 3, name: "Sunnyverse", owned: true },
  { user_id: 3, name: "Nexus" },
  { user_id: 2, name: "Aurum", owned: true },
  { user_id: 2, name: "Harmonics", owned: true },
  { user_id: 2, name: "Quinn" },
  { user_id: 2, name: "Dreamward", owned: true },
  { user_id: 3, name: "Buffy" },
  { user_id: 3, name: "Eos" },
])

puts "Assigning tags to characters..."
CharacterTag.create!([
  { character_id: 26, tag_id: 4 },
])

puts "Assigning settings to characters..."
Setting::Character.create!([
  { character_id: 10, setting_id: 4 },
  { character_id: 12, setting_id: 7 },
  { character_id: 14, setting_id: 6 },
  { character_id: 15, setting_id: 1 },
  { character_id: 16, setting_id: 1 },
  { character_id: 17, setting_id: 4 },
  { character_id: 18, setting_id: 6 },
  { character_id: 19, setting_id: 9 },
  { character_id: 20, setting_id: 2 },
  { character_id: 21, setting_id: 1 },
  { character_id: 22, setting_id: 1 },
  { character_id: 26, setting_id: 3 },
  { character_id: 27, setting_id: 3 },
  { character_id: 28, setting_id: 3 },
  { character_id: 29, setting_id: 1 },
  { character_id: 30, setting_id: 4 },
  { character_id: 31, setting_id: 9 },
  { character_id: 33, setting_id: 1 },
])

puts "Assigning tags to galleries..."
GalleryTag.create!([
  { gallery_id: 26, tag_id: 4 },
  { gallery_id: 28, tag_id: 4 },
  { gallery_id: 27, tag_id: 4 },
])

puts "Attaching settings to each other..."
Tag::SettingTag.create!([
  { tagged_id: 6, setting_id: 8 },
  { tagged_id: 12, setting_id: 1 },
  { tagged_id: 8, setting_id: 1 },
])

puts "Attaching tags to posts..."
PostTag.create!([
  { post_id: 1, tag_id: 1 },
  { post_id: 1, tag_id: 2 },
  { post_id: 1, tag_id: 3 },
])

puts "Attaching settings to posts..."
Setting::Post.create!([
  { post_id: 12, setting_id: 1 },
  { post_id: 8, setting_id: 1 },
  { post_id: 9, setting_id: 1 },
  { post_id: 10, setting_id: 1 },
  { post_id: 11, setting_id: 1 },
  { post_id: 4, setting_id: 1 },
  { post_id: 3, setting_id: 1 },
  { post_id: 5, setting_id: 1 },
  { post_id: 6, setting_id: 1 },
  { post_id: 7, setting_id: 1 },
  { post_id: 12, setting_id: 9 },
  { post_id: 8, setting_id: 9 },
  { post_id: 9, setting_id: 9 },
  { post_id: 10, setting_id: 9 },
  { post_id: 11, setting_id: 9 },
  { post_id: 13, setting_id: 9 },
  { post_id: 14, setting_id: 9 },
  { post_id: 15, setting_id: 9 },
  { post_id: 16, setting_id: 9 },
  { post_id: 17, setting_id: 9 },
  { post_id: 18, setting_id: 9 },
  { post_id: 19, setting_id: 9 },
  { post_id: 20, setting_id: 9 },
  { post_id: 21, setting_id: 9 },
  { post_id: 22, setting_id: 9 },
  { post_id: 23, setting_id: 9 },
  { post_id: 24, setting_id: 9 },
  { post_id: 25, setting_id: 9 },
  { post_id: 26, setting_id: 9 },
  { post_id: 27, setting_id: 9 },
  { post_id: 28, setting_id: 9 },
  { post_id: 29, setting_id: 9 },
  { post_id: 30, setting_id: 9 },
  { post_id: 31, setting_id: 9 },
  { post_id: 4, setting_id: 9 },
  { post_id: 3, setting_id: 9 },
  { post_id: 5, setting_id: 9 },
  { post_id: 6, setting_id: 9 },
  { post_id: 7, setting_id: 9 },
  { post_id: 1, tag_id: 1 },
  { post_id: 1, tag_id: 2 },
  { post_id: 1, tag_id: 3 },
  { post_id: 32, setting_id: 3 },
])
