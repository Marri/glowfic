/* global gon, createSelect2, createTagSelect, processResults, queryTransform */
var galleryIds, oldTemplate;
var galleryGroupIds = [];
var galleryGroups = {};
var characterIconsBox;

$(document).ready(function() {
  characterIconsBox = $('#character-icon-selector .character-galleries-simple');
  gon.gallery_groups.forEach(function(galleryGroup) {
    galleryGroups[galleryGroup.id] = galleryGroup;
  });
  galleryIds = $("#character_ungrouped_gallery_ids").val() || [];
  galleryGroupIds = $("#character_gallery_group_ids").val() || [];

  createSelect2("#character_setting_ids", {
    minimumResultsForSearch: 10,
    placeholder: 'Setting',
    tags: true
  });

  createSelect2("#character_ungrouped_gallery_ids", {
    minimumResultsForSearch: 10,
    placeholder: 'Default Gallery'
  });

  bindIcons();

  oldTemplate = $("#character_template_id").val();
  $("#new_template").change(function() {
    $("#character_template_attributes_name").val('');
    $("#character_template_attributes_id").val('');

    if ($("#new_template").is(":checked")) {
      $("#create_template").show();
      oldTemplate = $("#character_template_id").val();
      $("#character_template_id").attr("disabled", true).val('').trigger("change.select2");
    } else {
      $("#create_template").hide();
      $("#character_template_id").attr("disabled", false).val(oldTemplate).trigger("change.select2");
    }
  });

  $("#character_template_id").change(function() {
    $("#character_template_attributes_id").val('');
    $("#character_template_attributes_name").val('');
  });

  $("#character_ungrouped_gallery_ids").change(function() {
    $("#character_default_icon_id").val('');

    var newGalleryIds = $(this).val() || [];

    // a gallery was removed
    if (galleryIds.length > newGalleryIds.length) {
      var removedGallery = $(galleryIds).not(newGalleryIds).get(0);
      galleryIds = newGalleryIds;
      if (findGalleryInGroups(removedGallery)) return;
      characterIconsBox.find("#gallery"+removedGallery).remove();

      // if no more galleries are left, display galleryless icons
      if (characterIconsBox.find("[id^='gallery']").length === 0) {
        displayGallery('0');
      }
      return;
    }

    var newId = $(newGalleryIds).not(galleryIds).get(0);
    galleryIds = newGalleryIds;
    characterIconsBox.find("#gallery0").remove();

    // display only if not visible (for gallery groups)
    if (characterIconsBox.find("#gallery" + newId).length === 0) displayGallery(newId);
  });

  $("#character_gallery_group_ids").change(function() {
    $("#character_default_icon_id").val('');

    var newGalleryGroupIds = $(this).val() || [];

    // a gallery group was removed
    if (galleryGroupIds.length > newGalleryGroupIds.length) {
      var removedGroup = $(galleryGroupIds).not(newGalleryGroupIds).get(0);
      galleryGroupIds = newGalleryGroupIds;
      if (removedGroup.substring(0, 1) === '_') return; // skip uncreated tags

      var group = galleryGroups[parseInt(removedGroup)];
      delete galleryGroups[parseInt(removedGroup)];

      // delete unfound galleries from icons list
      group.gallery_ids.forEach(function(galleryId) {
        if (findGalleryInGroups(galleryId) || galleryIds.indexOf(galleryId.toString()) >= 0) return;
        characterIconsBox.find("#gallery" + galleryId).remove();
        galleryIds = $.makeArray($(galleryIds).not([galleryId.toString()]));
      });

      // if no more galleries remain, display galleryless icons
      if (characterIconsBox.find("[id^='gallery']").length === 0) {
        displayGallery('0');
      }
      return;
    }

    var newId = $(newGalleryGroupIds).not(galleryGroupIds).get(0);
    galleryGroupIds = newGalleryGroupIds;
    if (typeof newId === 'undefined') return;
    if (newId.substring(0, 1) === '_') return; // skip uncreated tags

    // fetch galleryGroup galleryIds
    $.authenticatedGet('/api/v1/tags/'+newId, {user_id: gon.user_id}, function(resp) {
      var ids = resp.gallery_ids;
      galleryGroups[resp.id] = {gallery_ids: ids};

      if (ids.length === 0) return; // return if empty

      characterIconsBox.find("#gallery0").remove();
      ids.forEach(function(id) {
        if (characterIconsBox.find("#gallery" + id).length === 0) {
          displayGallery(id);
        }
      });
    });
  });

  createTagSelect("Setting", "setting", "character");
  createSelect2("#character_gallery_group_ids", {
    placeholder: 'Enter gallery group(s) separated by commas',
    ajax: {
      url: '/api/v1/tags',
      data: function(params) {
        var data = queryTransform(params);
        data.t = 'GalleryGroup';
        data.user_id = gon.user_id;
        return data;
      },
      processResults: function(data, params) {
        params.page = params.page || 1;
        var total = this._request.getResponseHeader('Total');
        var results = processResults(data, params, total);

        // Remove duplicates
        var existingIds = $("#character_gallery_group_ids").val() || [];
        var validResults = [];
        results.results.forEach(function(gallery) {
          if (!existingIds.includes(gallery.id.toString())) validResults.push(gallery);
        });
        results.results = validResults;

        return results;
      },
    },
    width: '300px'
  });
});

function findGalleryInGroups(galleryId) {
  galleryId = parseInt(galleryId);
  var found = false;
  Object.keys(galleryGroups).forEach(function(groupId) {
    if (galleryGroups[groupId].gallery_ids.indexOf(galleryId) >= 0) found = true;
  });
  return found;
}

function displayGallery(newId) {
  $.authenticatedGet('/api/v1/galleries/'+newId, {}, function(resp) {
    var galleryObj = $("<div>").attr({id: 'gallery'+newId}).data('id', newId);
    galleryObj.append("<br />");
    galleryObj.append($("<b>").attr({class: 'gallery-name'}).append(resp.name));
    galleryObj.append("<br />");
    var galleryIcons = $("<div>").attr({class: 'gallery-icons'});
    galleryObj.append(galleryIcons);
    for (var i = 0; i < resp.icons.length; i++) {
      var url = resp.icons[i].url;
      var keyword = resp.icons[i].keyword;
      var id = resp.icons[i].id;
      var galleryIcon = $("<img>").attr({src: url, alt: keyword, title: keyword, class: 'icon character-icon'}).data('id', id);
      galleryIcons.append(galleryIcon);
    }
    characterIconsBox.append(galleryObj);
    bindIcons(galleryObj);
  }, 'json');
}

function bindIcons(obj) {
  if (gon.mod_editing) return; // Mods can't change icons, so don't present the UI
  obj = obj || window.body;
  $(".character-icon", obj).click(function() {
    if ($(this).hasClass('selected-icon')) {
      $(this).removeClass('selected-icon');
      updateIcon('');
      return;
    }

    $(".selected-icon").removeClass('selected-icon');
    $(this).addClass('selected-icon');
    updateIcon($(this).data('id'));
  });
}

function updateIcon(id) {
  if (gon.character_id) {
    $.authenticatedAjax({
      url: '/api/v1/characters/'+gon.character_id,
      type: 'PUT',
      data: {character: {default_icon_id: id}},
    });
  } else {
    $("#character_default_icon_id").val(id);
  }
}
