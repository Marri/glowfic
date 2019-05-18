ContentWarning.create!([
  {id: 1, user_id: 5, name: "warning 1", created_at: "2019-05-17 19:25:29", updated_at: "2019-05-17 19:25:29", type: "ContentWarning", description: nil, owned: false},
  {id: 2, user_id: 5, name: "warning 2", created_at: "2019-05-17 19:25:29", updated_at: "2019-05-17 19:25:29", type: "ContentWarning", description: nil, owned: false},
  {id: 3, user_id: 5, name: "warning 3", created_at: "2019-05-17 19:25:29", updated_at: "2019-05-17 19:25:29", type: "ContentWarning", description: nil, owned: false}
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
TagTag.create!([
  { tagged_id: 3, tag_id: 9 },
  { tagged_id: 9, tag_id: 2 },
  { tagged_id: 5, tag_id: 2 },
])

puts "Attaching tags to posts..."
