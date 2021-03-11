var imageIds = [];
var skipWarning = false;
$(document).ready(function() {
  bindGalleryIcons(".add-gallery-icon");

  $(".select-all").click(function() {
    var galleryId = $(this).val();
    var icons = $("#icons-"+galleryId+" .gallery-icon img");
    $.each(icons, function(index, icon) {
      selectIcon(icon);
    });
  });

  $("#add-gallery-icons").submit(function() {
    if (imageIds.length < 1) return false;
    $("#image_ids").val(imageIds);
    skipWarning = true;
    return true;
  });

  $(".gallery-minmax").click(function() {
    var galleryId = $(this).data('id');

    // Hide icons if they're already visible
    if ($("#icons-" + galleryId).is(':visible')) {
      $("#icons-" + galleryId).hide();
      $("#minmax-" + galleryId).text("+");
      return;
    }

    // Show icons if they're hidden
    $("#icons-" + galleryId).show();
    $("#minmax-" + galleryId).text("-");
    if ($("#icons-" + galleryId + " .icon").length > 0) { return; }

    // Load and bind icons if they have not already been loaded
    $.authenticatedGet("/api/v1/galleries/" + galleryId, {}, function(resp) {
      $.each(resp.icons, function(index, icon) {
        var iconDiv = $("<div>").attr({class: 'gallery-icon'});
        var iconImg = $("<img>").attr({src: icon.url, alt: icon.keyword, title: icon.keyword, 'class': 'icon add-gallery-icon', 'data-id': icon.id});
        iconDiv.append(iconImg).append("<br>").append($("<span>").attr({class: 'icon-keyword'}).append(icon.keyword));
        $("#icons-" + galleryId).append(iconDiv);
      });
      bindGalleryIcons("#icons-" + galleryId + " .add-gallery-icon");
    });
  });
});

$(window).on('beforeunload', function() {
  if (skipWarning || imageIds.length === 0) return;
  return "Are you sure you wish to navigate away? You have " + imageIds.length + " image(s) selected.";
});

function bindGalleryIcons(selector) {
  $(selector).click(function() {
    selectIcon(this);
  });
}

function selectIcon(icon) {
  $(icon).toggleClass('selected-icon');
  if ($(icon).hasClass('selected-icon')) {
    imageIds.push(icon.dataset.id);
  } else {
    imageIds.pop(icon.dataset.id);
  }
}
