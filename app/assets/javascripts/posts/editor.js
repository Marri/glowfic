//= require posts/edit_notes
/* global gon, tinyMCE, resizeScreenname, createTagSelect, createSelect2, queryTransform, processResults */

var tinyMCEInit = false, shownIcons = [];
var iconSelectBox;

$(document).ready(function() {
  $("#post_id").select2({
    ajax: {
      delay: 200,
      url: '/api/v1/posts',
      dataType: 'json',
      data: function(params) { return queryTransform(params); },
      processResults: function(data, params) {
        var total = this._request.getResponseHeader('Total');
        return processResults(data, params, total, 'subject');
      },
      cache: true
    },
    placeholder: '— Choose Post —',
    allowClear: true,
    width: '300px'
  });

  $("#relation").select2({width: '300px'});

  setupMetadataEditor();
  fixButtons();
  iconSelectBox = $('#reply-icon-selector');

  if ($("#post-editor .view-button").length > 0) setupWritableEditor();
});

function setupMetadataEditor() {
  // Adding Select2 UI to relevant selects
  createSelect2('#post_board_id', {
    width: '200px',
    minimumResultsForSearch: 20
  });

  createSelect2('#post_section_id', {
    width: '200px',
    minimumResultsForSearch: 20
  });

  createSelect2('#post_privacy', {
    width: '200px',
    minimumResultsForSearch: 20
  });

  createSelect2('#post_viewer_ids', {
    width: '200px',
    minimumResultsForSearch: 20,
    placeholder: 'Choose user(s) to view this post'
  });

  createSelect2('#post_unjoined_author_ids', {
    width: '300px',
    minimumResultsForSearch: 20,
    placeholder: 'Choose user(s) to invite to reply to this post'
  });

  createSelect2('.post_link_relationship', {
    width: '200px',
    minimumResultsForSearch: 20,
    placeholder: 'Choose relationship'
  });

  createSelect2('.post_link_linked_post_id', {
    width: '300px',
    minimumResultsForSearch: 20,
    placeholder: 'Choose a post'
  });

  createTagSelect("Label", "label", "post");
  createTagSelect("Setting", "setting", "post");
  createTagSelect("ContentWarning", "content_warning", "post");

  if ($("#post_privacy").val() !== 'access_list') {
    $("#access_list").hide();
  }

  if ($("#post_section_id").val() === '') setSections();
  $("#post_board_id").change(function() { setSections(); });

  $("#post_privacy").change(function() {
    if ($(this).val() === 'access_list') {
      $("#access_list").show();
    } else {
      $("#access_list").hide();
    }
  });

  $("#post_unjoined_author_ids").change(function() {
    var numAuthors = $("#post_unjoined_author_ids :selected").length;
    $("#post_authors_locked").prop('checked', (numAuthors > 0));
  });
}

function setupWritableEditor() {
  $('.post-editor-expander').click(function() {
    $(this).children(".info").hide();
    $(this).children(".hidden").show();
  });

  // SET UP WRITABLE EDITOR:

  // TODO fix hack
  // Hack because having In Thread characters as a group in addition to Template groups
  // duplicates characters in the dropdown, and therefore multiple options are selected
  var selectd;
  $("#active_character option[selected]").each(function() {
    if (!selectd) selectd = this;
    $(this).prop("selected", false);
  });
  $(selectd).prop("selected", true);

  // TODO fix hack
  // Only initialize TinyMCE if it's required
  if ($("#rtf").hasClass('selected') === true) {
    setupTinyMCE();
  }

  fixWritableFormCaching();

  // Bind both change() and keyup() in the icon keyword dropdown because Firefox doesn't
  // respect up/down key selections in a dropdown as a valid change() trigger
  $("#icon_dropdown").change(function() { setIconFromId($(this).val()); });
  $("#icon_dropdown").keyup(function() { setIconFromId($(this).val()); });

  var editorHelp = $("#editor-help-box");
  var defaultHelpWidth = 500;
  var defaultHelpHeight = 700;
  editorHelp.dialog({
    autoOpen: false,
    title: 'Editor Help',
    width: defaultHelpWidth,
    height: defaultHelpHeight
  });

  $('#rtf, #html').click(toggleEditor);
  $('#editor-help').click(function() {
    if (editorHelp.dialog('isOpen')) {
      editorHelp.dialog('close');
    } else {
      var width = Math.min($(window).width()-20, defaultHelpWidth);
      var height = Math.min($(window).height()-20, defaultHelpHeight);
      editorHelp.dialog('option', {width: width, height: height}).dialog('open');
      editorHelp.dialog('open');
    }
  });

  $("#swap-character").click(function() {
    $('#character-selector').toggle();
    $('#alias-selector').hide();
    $('html, body').scrollTop($("#post-editor").offset().top);
  });

  $("#swap-alias").click(function() {
    $('#alias-selector').toggle();
    $('#character-selector').hide();
    $('html, body').scrollTop($("#post-editor").offset().top);
  });

  $("#active_character, #character_alias").on('select2:close', function() {
    $('html, body').scrollTop($("#post-editor").offset().top);
  });

  $("#active_character").change(function() {
    // Set the ID
    var id = $(this).val();
    $("#reply_character_id").val(id);
    getAndSetCharacterData(id);
  });

  $(".char-access-icon").click(function() {
    var id = $(this).data('character-id');
    $("#reply_character_id").val(id);
    $("#active_character").val(id).trigger('change.select2');
    getAndSetCharacterData(id);
  });

  $("#character_alias").change(function() {
    // Set the ID
    var id = $(this).val();
    $("#reply_character_alias_id").val(id);
    $("#post-editor .post-character #name").html($('#character_alias option:selected').text());
    $('#alias-selector').hide();
    $("#post-editor .post-character").data('alias-id', id);
  });

  // Hides selectors when you hit the escape key
  $(document).bind("keydown", function(e) {
    e = e || window.event;
    var charCode = e.which || e.keyCode;
    if (charCode === 27) {
      $('#icon-overlay').hide();
      iconSelectBox.hide();
      $('#character-selector').hide();
    }
  });

  // Hides selectors when you click outside them
  $(document).click(function(e) {
    var target = e.target;

    if (!$(target).closest('#current-icon-holder').length &&
        !$(target).closest(iconSelectBox).length) {
      $('#icon-overlay').hide();
      iconSelectBox.hide();
    }

    if (!$(target).closest('#character-selector').length &&
        !$(target).closest('#swap-character').length) {
      $('#character-selector').hide();
    }

    if (!$(target).closest('#alias-selector').length &&
        !$(target).closest('#swap-alias').length) {
      $('#alias-selector').hide();
    }
  });
}

function fixWritableFormCaching() {
  // Hack to deal with Firefox's "helpful" caching of form values on soft refresh (now via IDs)
  var selectedCharID = $("#reply_character_id").val();
  var displayCharID = String($("#post-editor .post-character").data('character-id'));
  var selectedIconID = $("#reply_icon_id").val();
  var displayIconID = String($("#current-icon").data('icon-id'));
  var selectedAliasID = $("#reply_character_alias_id").val();
  var displayAliasID = String($("#post-editor .post-character").data('alias-id'));
  if (selectedCharID === displayCharID) {
    if ($(".gallery-icon").length > 1) { /* Bind icon & gallery only if not resetting character, else it duplicate binds */
      bindIcon();
      bindGallery();
    }
    if (selectedIconID !== displayIconID) {
      setIconFromId(selectedIconID); // Handle the case where just the icon was cached
    }
    if (selectedAliasID !== displayAliasID) {
      setAliasFromID(selectedAliasID);
    }
  } else {
    getAndSetCharacterData(selectedCharID, {restore_icon: true, restore_alias: true});
    $("#active_character").val(selectedCharID).trigger("change.select2");
  }

  // Set the quick-switcher's selected character
  setSwitcherListSelected(selectedCharID);
}

function toggleEditor() {
  if (this.id === 'rtf') {
    $("#html").removeClass('selected');
    $("#editor_mode").val('rtf');
    $(this).addClass('selected');
    if (tinyMCEInit) {
      tinyMCE.execCommand('mceAddEditor', true, 'post_content');
      tinyMCE.execCommand('mceAddEditor', true, 'reply_content');
    } else {
      setupTinyMCE();
    }
  } else if (this.id === 'html') {
    $("#rtf").removeClass('selected');
    $("#editor_mode").val('html');
    $(this).addClass('selected');
    tinyMCE.execCommand('mceRemoveEditor', false, 'post_content');
    tinyMCE.execCommand('mceRemoveEditor', false, 'reply_content');
  }
}

function bindGallery() {
  iconSelectBox.find('img').click(function() {
    var id = $(this).data('icon-id');
    setIconFromId(id, $(this));
  });
}

function bindIcon() {
  $('#current-icon-holder').click(function() {
    $('#icon-overlay').toggle();
    iconSelectBox.toggle();
    $('html, body').scrollTop($("#post-editor").offset().top);
  });
}

function galleryString(gallery, multiGallery) {
  var iconsString = "";
  var icons = gallery.icons;

  for (var i=0; i<icons.length; i++) {
    iconsString += iconString(icons[i]);
  }

  if (!multiGallery) return iconsString;

  var nameString = "<div class='gallery-name'>" + gallery.name + "</div>";
  return "<div class='gallery-group'>" + nameString + iconsString + "</div>";
}

function iconString(icon) {
  var imgId = icon.id;
  var imgUrl = icon.url;
  var imgKey = icon.keyword;
  shownIcons.push(icon.id);

  if (!icon.skip_dropdown) $("#icon_dropdown").append($("<option>").attr({value: imgId}).append(imgKey));
  var iconImg = $("<img>").attr({src: imgUrl, alt: imgKey, title: imgKey, 'class': 'icon img-'+imgId, 'data-icon-id': imgId});
  return $("<div>").attr('class', 'gallery-icon').append(iconImg).append("<br />").append(imgKey)[0].outerHTML;
}

function setupTinyMCE() {
  var selector = 'textarea.tinymce';
  if (typeof tinyMCE === 'undefined') {
    setTimeout(arguments.callee, 50);
  } else {
    var height = ($(selector).height() || 150) + 15;
    tinyMCE.init({
      selector: selector,
      menubar: false,
      toolbar: ["bold italic underline strikethrough | link image | blockquote hr bullist numlist | undo redo"],
      branding: false,
      plugins: "wordcount,image,hr,link,autoresize,paste",
      paste_as_text: true,
      custom_undo_redo_levels: 10,
      content_css: gon.tinymce_css_path,
      statusbar: true,
      elementpath: false,
      resize: true,
      autoresize_bottom_margin: 5,
      min_height: height,
      browser_spellcheck: true,
      relative_urls: false,
      remove_script_host: true,
      document_base_url: gon.base_url,
      body_class: gon.editor_class,
      contextmenu: false,
      cache_suffix: '?v=5.1.4.1'
    });
    tinyMCEInit = true;
  }
}

function setFormData(characterId, resp, options) {
  var restoreIcon = false;
  var restoreAlias = false;

  if (typeof options !== 'undefined') {
    restoreIcon = options.restore_icon;
    restoreAlias = options.restore_alias;
  }

  setSwitcherListSelected(characterId);

  var selectedIconID = $("#reply_icon_id").val();
  var selectedAliasID = $("#reply_character_alias_id").val();
  $("#character-selector").hide();

  setInfoBoxFields(characterId, resp.name, resp.screenname);

  setAliases(resp.aliases, resp.name);
  setAliasFromID('');
  if (restoreAlias)
    setAliasFromID(selectedAliasID);
  else if (resp.alias_id_for_post)
    setAliasFromID(resp.alias_id_for_post);

  setGalleriesAndDefault(resp.galleries, resp.default_icon);
  setIcon('');
  if (restoreIcon)
    setIconFromId(selectedIconID);
  else if (resp.default_icon)
    setIcon(resp.default_icon.id, resp.default_icon.url, resp.default_icon.keyword, resp.default_icon.keyword);
}

function setInfoBoxFields(characterId, name, screenname) {
  // Display the correct name/screenname fields
  var spacer = $("#post-editor #post-author-spacer");
  var characterNameBox = $("#post-editor .post-character");
  if (name) {
    spacer.hide();
    characterNameBox.show();
  } else {
    spacer.show();
    characterNameBox.hide();
  }
  characterNameBox.data('character-id', characterId);
  $("#post-editor .post-character #name").html(name);

  var screennameBox = $("#post-editor .post-screenname");
  if (screenname) {
    screennameBox.show().html(screenname);
    resizeScreenname(screennameBox);
  } else {
    screennameBox.hide().html(screenname);
  }
}

function setAliases(aliases, name) {
  // Display alias selector if relevant
  var aliasList = $("#character_alias");
  aliasList.empty();
  aliasList.append($("<option>").attr({value: ''}).append(name));
  if (aliases.length > 0) {
    $("#swap-alias").show();
    for (var i=0; i<aliases.length; i++) {
      aliasList.append($("<option>").attr({value: aliases[i].id}).append(aliases[i].name));
    }
  } else {
    $("#swap-alias").hide();
  }
}

function setAliasFromID(selectedAliasID) {
  var correctName = $("#character_alias option[value=\""+selectedAliasID+"\"]").text();
  $("#post-editor .post-character #name").html(correctName);
  $("#post-editor .post-character").data('alias-id', selectedAliasID);
  $("#character_alias").val(selectedAliasID).trigger("change.select2");
  $("#reply_character_alias_id").val(selectedAliasID);
}

function setGalleriesAndDefault(galleries, defaultIcon) {
  shownIcons = [];

  $("#current-icon-holder").unbind();
  $("#icon_dropdown").empty().append('<option value="">No Icon</option>');

  iconSelectBox.html('');

  // Remove pointer and skip galleries if no galleries attached to character
  if (galleries.length === 0 && !defaultIcon) {
    $("#current-icon").removeClass('pointer');
    return;
  }

  // Display default icon
  $("#current-icon").addClass('pointer');

  // Calculate new galleries
  var multiGallery = galleries.length > 1;
  for (var j = 0; j < galleries.length; j++) {
    iconSelectBox.append(galleryString(galleries[j], multiGallery));
  }

  // If no default and no icons in any galleries, remove pointer
  if (!defaultIcon && shownIcons.length === 0) {
    $("#current-icon").removeClass('pointer');
    return;
  }

  if (defaultIcon && shownIcons.indexOf(defaultIcon.id) < 0) iconSelectBox.append(iconString(defaultIcon));
  iconSelectBox.append(iconString({id: '', url: gon.no_icon_path, keyword: 'No Icon', skip_dropdown: true}));
  bindGallery();
  bindIcon();
}

function getAndSetCharacterData(characterId, options) {
  // Handle page interactions

  // Handle special case where just setting to your base account
  if (characterId === '') {
    var avatar = gon.editor_user.avatar;
    var data = {aliases: [], galleries: []};
    if (avatar) {
      data.default_icon = avatar;
      data.galleries.push({icons: [avatar]});
    }
    setFormData(characterId, data, options);
    return; // Don't need to load data from server
  }

  var postID = $("#reply_post_id").val();
  $.authenticatedGet('/api/v1/characters/' + characterId, {post_id: postID}, function(resp) {
    setFormData(characterId, resp, options);
  });
}

function setIconFromId(id, img) {
  // Assumes the icon selection box is populated with icons with the correct values
  if (id === "") return setIcon(id);
  if (typeof img === 'undefined') img = $('.img-'+id);
  return setIcon(id, img.attr('src'), img.attr('title'), img.attr('alt'));
}

function setIcon(id, url, title, alt) {
  // Handle No Icon case
  if (id === "") {
    url = gon.no_icon_path;
    title = "No Icon";
    alt = "";
  }

  // Hide icon UI elements
  $('#icon-overlay').hide();
  iconSelectBox.hide();

  // Set necessary form values
  $("#reply_icon_id").val(id);
  $("#icon_dropdown").val(id);
  $("#current-icon").data('icon-id', id);

  // Set current icon UI elements
  $("#current-icon").attr('src', url);
  $("#current-icon").attr('title', title);
  $("#current-icon").attr('alt', alt);
}

function setSections() {
  var boardId = $("#post_board_id").val();
  $.authenticatedGet("/api/v1/boards/"+boardId, {}, function(resp) {
    var sections = resp.board_sections;
    if (sections.length > 0) {
      $("#section").show();
      $("#post_section_id").empty().append('<option value="">— Choose Section —</option>');
      for (var i = 0; i < sections.length; i++) {
        $("#post_section_id").append($("<option>").attr({value: sections[i].id}).append(sections[i].name));
      }
      $("#post_section_id").trigger("change.select2");
    } else {
      $("#post_section_id").val("").trigger("change.select2");
      $("#section").hide();
    }
  }, 'json');
}

function setSwitcherListSelected(characterId) {
  // for quick selector
  $(".char-access-icon.semiopaque").removeClass('semiopaque').addClass('pointer');
  $(".char-access-icon").each(function() {
    if (String($(this).data('character-id')) === String(characterId)) $(this).addClass('semiopaque').removeClass('pointer');
  });
}

function fixButtons() {
  $(".icon-row-add").hide().unbind();
  $(".icon-row-add").last().show();
  $(".icon-row-rem").show();
  $(".icon-row-rem").first().hide();
  bindAdd();
  bindRem();
}

function bindAdd() {
  $(".icon-row-add").click(function() {
    addNewRow();
    fixButtons();
  });
}

function addNewRow() {
  var oldRow = $(".link-row:last");
  var newRow = oldRow.clone();
  var index = oldRow.data('index') + 1;
  newRow.data('index', index);

  // clear all input values in the clone
  var inputs = newRow.find('input');
  inputs.val('');

  newRow.insertBefore($("#post-notes"));
}

function bindRem() {
  $(".icon-row-rem").click(function() {
    var remRow = $(this).parent();
    remRow.remove();
    fixButtons();
  });
}
