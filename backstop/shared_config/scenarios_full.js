module.exports = [
  {
    label: "flash_error",
    path: "boards/-1",
    selectors: [".flash"]
  },
  {
    label: "flash_success",
    path: "characters/27/edit",
    selectors: [".flash.success"],
    clickSelectors: ["input.button"],
    delay: 0,
    postInteractionWait: 200
  },
  {
    label: "home",
    path: "",
    misMatchThreshold: 0.00,
  },
  {
    label: "about_contact",
    path: "contact",
    selectors: ["#content"]
  },
  {
    label: "boards",
    path: "boards",
    selectors: ["#content"]
  },
  {
    label: "board_show_open",
    path: "boards/3",
    selectors: ["#content"]
  },
  {
    label: "board_edit",
    path: "boards/1/edit?proofer-ignore",
    selectors: ["#content"]
  },
  {
    label: "board_show_sections",
    path: "boards/1",
    selectors: ["#content"]
  },
  {
    label: "board_section_edit",
    path: "board_sections/1/edit",
    selectors: ["#content"]
  },
  {
    label: "characters_icon_split",
    path: "users/3/characters?character_split=template&view=icons",
    selectors: ["#content"]
  },
  {
    label: "characters_list_combined",
    path: "users/3/characters?character_split=none&view=list",
    selectors: ["#content"]
  },
  {
    label: "character_edit",
    path: "characters/27/edit",
    selectors: ["#content"]
  },
  {
    label: "character_replace",
    path: "characters/27/replace",
    selectors: ["#content"]
  },
  {
    label: "character_show",
    path: "characters/27",
    selectors: ["#content"]
  },
  {
    label: "character_galleries",
    path: "characters/27?view=galleries",
    selectors: ["#content"]
  },
  {
    label: "characters_search",
    path: "characters/search?author_id=1&name=a&search_name=true&search_screenname=true&search_nickname=true&commit=Search",
    selectors: ["#content"]
  },
  {
    label: "characters_facecasts",
    path: "characters/facecasts",
    selectors: ["#content"]
  },
  {
    label: "favorites",
    path: "favorites?view=bucket",
    selectors: ["#content"]
  },
  {
    label: "galleries",
    path: "users/3/galleries",
    selectors: ["#content"]
  },
  {
    label: "gallery_add_new",
    path: "galleries/0/add?proofer-ignore",
    selectors: ["#content"]
  },
  {
    label: "gallery_add_existing",
    path: "galleries/19/add?type=existing",
    selectors: ["#content"]
  },
  {
    label: "gallery_show",
    path: "galleries/26",
    selectors: ["#content"]
  },
  {
    label: "galleryless_show",
    path: "galleries/0",
    selectors: ["#content"]
  },
  {
    label: "gallery_edit",
    path: "galleries/26/edit",
    selectors: ["#content"]
  },
  {
    label: "icon_show",
    path: "icons/93",
    selectors: ["#content"]
  },
  {
    label: "icon_edit",
    path: "icons/93/edit",
    selectors: ["#content"]
  },
  {
    label: "messages_index",
    path: "messages",
    selectors: ["#content"]
  },
  {
    label: "message_show",
    path: "messages/2",
    selectors: ["#content"]
  },
  {
    label: "message_new",
    path: "messages/new?recipient_id=1",
    selectors: ["#content"]
  },
  {
    label: "news",
    path: "news",
    selectors: ["#content"]
  },
  {
    label: "posts_search",
    path: "posts/search?character_id=19&author_id[]=3&author_id[]=2&subject=a",
    selectors: ["#content"]
  },
  {
    label: "posts_unread",
    path: "posts/unread",
    selectors: ["#content"],
    misMatchThreshold: 0.00
  },
  {
    label: "posts_hidden",
    path: "posts/hidden",
    selectors: ["#content"]
  },
  {
    label: "posts_owed",
    path: "posts/owed",
    selectors: ["#content"]
  },
  {
    label: "post_show",
    path: "posts/3",
    selectors: ["#content"],
    delay: 1000
  },
  {
    label: "post_show_html",
    path: "posts/2?page=2&per_page=5&proofer-ignore",
    selectors: ["#content"],
    onReadyScript: 'puppet/paginatorHover.js',
    delay: 1000,
    misMatchThreshold: 0
  },
  {
    label: "post_edit",
    path: "posts/3/edit",
    selectors: ["#content"],
    delay: 1000
  },
  {
    label: "post_flat",
    path: "posts/3?view=flat",
    selectors: ["#content"]
  },
  {
    label: "post_menu",
    path: "posts/3",
    selectors: ["#post-menu-box"],
    clickSelectors: ['#post-menu'],
    delay: 0,
    postInteractionWait: 200
  },
  {
    label: "icon_selector",
    path: "posts/new",
    selectors: ["#reply-icon-selector"],
    clickSelectors: ['#current-icon-holder'],
    delay: 0,
    postInteractionWait: 200
  },
  {
    label: "character_selector",
    path: "posts/new",
    selectors: ["#post_form"],
    clickSelectors: ['#swap-character', '#select2-active_character-container'],
    delay: 200,
    postInteractionWait: 1000
  },
  {
    label: "replies_search",
    path: "replies/search?commit=true&icon_id=89",
    selectors: ["#content"]
  },
  {
    label: "reply_history",
    path: "replies/3/history",
    selectors: ["#content"]
  },
  {
    label: "reply_edit",
    path: "replies/37/edit",
    selectors: ["#content"],
    delay: 1000,
  },
  {
    label: "report_daily",
    path: "reports/daily?day=2012-09-13",
    selectors: ["#content"]
  },
  {
    label: "tags",
    path: "tags?view=Setting",
    selectors: ["#content"]
  },
  {
    label: "tag_show_info",
    path: "tags/5",
    selectors: ["#content"]
  },
  {
    label: "tag_edit",
    path: "tags/5/edit",
    selectors: ["#content"]
  },
  {
    label: "template_edit",
    path: "templates/11/edit",
    selectors: ["#content"]
  },
  {
    label: "users",
    path: "users",
    selectors: ["#content"]
  },
  {
    label: "user_show",
    path: "users/3",
    selectors: ["#content"]
  },
  {
    label: "user_edit",
    path: "users/3/edit",
    selectors: ["#content"]
  },
];
