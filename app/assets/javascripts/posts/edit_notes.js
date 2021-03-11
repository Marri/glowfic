var originalValue = '';
var submittedButton = '';

$(document).ready(function() {
  originalValue = $("#post_private_note").val();

  // If not on the reply page or otherwise not live editing notes
  if (!$(".edit-private-notes").length) return;

  $(".edit-private-notes").click(function() {
    $(".private-note").toggle();
    $(".private-note-editor").toggle();
    return false;
  });

  $(".save-private-note").click(function() {
    saveNoteChanges();
    return false;
  });

  $(".discard-private-note").click(function() {
    if (confirm('Are you sure you wish to discard your changes?')) {
      $("#post_private_note").val(originalValue);
    }
    return false;
  });

  $("#dialog-confirm").dialog({
    resizable: false,
    autoOpen: false,
    height: "auto",
    width: 400,
    modal: true,
    dialogClass: "no-close",
    buttons: {
      "Save Changes": function() {
        $(this).dialog("close");
        saveNoteChanges(function() { $(submittedButton).click(); });
      },
      "Discard Changes": function() {
        $(this).dialog("close");
        $("#post_private_note").val(originalValue);
        $(submittedButton).click();
      },
      "Cancel": function() {
        $(this).dialog("close");
      }
    }
  });

  var formButtons = $("#submit_button, #draft_button, #preview_button");
  formButtons.click(function() {
    submittedButton = "#" + $(this).attr('id');
    formButtons.not(this).prop('disabled', true);
    if ($("#post_private_note").val() === originalValue) { return true; }
    formButtons.not(this).prop('disabled', false);
    $("#dialog-confirm").dialog("open");
    return false;
  });
});

function noteFromData(note, encodedNote) {
  if (note) { return decodeURI(encodedNote); }
  return $("<em>").html("(You haven't written a note yet!)");
}

function saveNoteChanges(success) {
  $(".loading").show();

  var newNote = $("#post_private_note").val();
  var postID = $("#reply_post_id").val();

  $.authenticatedAjax({
    url: '/api/v1/posts/'+postID,
    type: 'PATCH',
    data: {'private_note': newNote},
    success: function(data) {
      originalValue = newNote;
      $(".loading").hide();
      $(".private-note").html(noteFromData(newNote, data.private_note));
      $(".private-note-editor").hide();
      $(".private-note").show();
      $(".saveconf").show().delay(2000).fadeOut();
      if (typeof success !== 'undefined') { success(); }
    },
    error: function() {
      $(".loading").hide();
      $(".saveerror").show();
    }
  });
}
