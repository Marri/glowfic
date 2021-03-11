ContentWarning.create!([
  { user_id: 5, name: "warning 1", type: "ContentWarning" },
  { user_id: 5, name: "warning 2", type: "ContentWarning" },
  { user_id: 5, name: "warning 3", type: "ContentWarning" },
])
GalleryGroup.create!([
  { user_id: 3, name: "JokerSherlock (SS)", type: "GalleryGroup" },
])
Setting.create!([
  { user_id: 3, name: "Earth", type: "Setting" },
  { user_id: 3, name: "Sunnyverse", type: "Setting", owned: true },
  { user_id: 3, name: "Nexus", type: "Setting" },
  { user_id: 2, name: "Aurum", type: "Setting", owned: true },
  { user_id: 2, name: "Harmonics", type: "Setting", owned: true },
  { user_id: 2, name: "Quinn", type: "Setting" },
  { user_id: 2, name: "Dreamward", type: "Setting", owned: true },
  { user_id: 3, name: "Buffy", type: "Setting" },
  { user_id: 3, name: "Eos", type: "Setting" },
])

puts "Assigning tags to characters..."
CharacterTag.create!([
  { character_id: 26, tag_id: 4 },
  { character_id: 10, tag_id: 8 },
  { character_id: 12, tag_id: 11 },
  { character_id: 14, tag_id: 10 },
  { character_id: 15, tag_id: 5 },
  { character_id: 16, tag_id: 5 },
  { character_id: 17, tag_id: 8 },
  { character_id: 18, tag_id: 10 },
  { character_id: 19, tag_id: 13 },
  { character_id: 20, tag_id: 6 },
  { character_id: 21, tag_id: 5 },
  { character_id: 22, tag_id: 5 },
  { character_id: 26, tag_id: 7 },
  { character_id: 27, tag_id: 7 },
  { character_id: 28, tag_id: 7 },
  { character_id: 29, tag_id: 5 },
  { character_id: 30, tag_id: 8 },
  { character_id: 31, tag_id: 13 },
  { character_id: 33, tag_id: 5 },
])

puts "Assigning tags to galleries..."
GalleryTag.create!([
  { gallery_id: 26, tag_id: 4 },
  { gallery_id: 28, tag_id: 4 },
  { gallery_id: 27, tag_id: 4 },
])

puts "Attaching settings to each other..."
Tag::SettingTag.create!([
  { tagged_id: 6, tag_id: 12 },
  { tagged_id: 12, tag_id: 5 },
  { tagged_id: 8, tag_id: 5 },
])

puts "Attaching tags to posts..."
PostTag.create!([
  { post_id: 12, tag_id: 5 },
  { post_id: 8, tag_id: 5 },
  { post_id: 9, tag_id: 5 },
  { post_id: 10, tag_id: 5 },
  { post_id: 11, tag_id: 5 },
  { post_id: 4, tag_id: 5 },
  { post_id: 3, tag_id: 5 },
  { post_id: 5, tag_id: 5 },
  { post_id: 6, tag_id: 5 },
  { post_id: 7, tag_id: 5 },
  { post_id: 12, tag_id: 13 },
  { post_id: 8, tag_id: 13 },
  { post_id: 9, tag_id: 13 },
  { post_id: 10, tag_id: 13 },
  { post_id: 11, tag_id: 13 },
  { post_id: 13, tag_id: 13 },
  { post_id: 14, tag_id: 13 },
  { post_id: 15, tag_id: 13 },
  { post_id: 16, tag_id: 13 },
  { post_id: 17, tag_id: 13 },
  { post_id: 18, tag_id: 13 },
  { post_id: 19, tag_id: 13 },
  { post_id: 20, tag_id: 13 },
  { post_id: 21, tag_id: 13 },
  { post_id: 22, tag_id: 13 },
  { post_id: 23, tag_id: 13 },
  { post_id: 24, tag_id: 13 },
  { post_id: 25, tag_id: 13 },
  { post_id: 26, tag_id: 13 },
  { post_id: 27, tag_id: 13 },
  { post_id: 28, tag_id: 13 },
  { post_id: 29, tag_id: 13 },
  { post_id: 30, tag_id: 13 },
  { post_id: 31, tag_id: 13 },
  { post_id: 4, tag_id: 13 },
  { post_id: 3, tag_id: 13 },
  { post_id: 5, tag_id: 13 },
  { post_id: 6, tag_id: 13 },
  { post_id: 7, tag_id: 13 },
  { post_id: 1, tag_id: 1 },
  { post_id: 1, tag_id: 2 },
  { post_id: 1, tag_id: 3 },
  { post_id: 32, tag_id: 7 },
])
