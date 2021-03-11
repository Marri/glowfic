/* global addUploadedIcon, setLoadingIcon, addCallback, failCallback */

var uploadedIcons = {};
var formKey = '';
var numFiles = 0;

$(document).ready(function() {
  var form = $('form.icon-upload');
  var submitButton = form.find('input[type="submit"]');
  var formData = form.data('form-data');

  $(".icon_files").each(function(index, fileInput) {
    bindFileInput($(fileInput), form, submitButton, formData);
  });

  $("form.icon-upload").submit(function() {
    var usedUrls = $.map($('form.icon-upload').find('input[id$=_url]'), function(input) { return $(input).val(); });
    var uploadedUrls = $.map(uploadedIcons, function(value, key) { return key; });
    var unusedUrls = uploadedUrls.filter(function(x) { return usedUrls.indexOf(x) < 0; });
    if (unusedUrls.length < 1) return true;
    deleteUnusedIcons($.map(unusedUrls, function(url) { return uploadedIcons[url]; }));
  });
});

function randomString() {
  return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
}

function bindFileInput(fileInput, form, submitButton, formData) {
  var limit = form.data('limit');
  var uploadArgs = {
    fileInput: fileInput,
    url: form.data('url'),
    type: 'POST',
    autoUpload: true,
    formData: formData,
    paramName: 'file', // S3 does not like nested name fields i.e. name="user[avatar_url]"
    dataType: 'XML', // S3 returns XML if success_action_status is set to 201
    replaceFileInput: false,
    disableImageResize: false,
    imageMaxWidth: 400,
    imageMaxHeight: 400,

    add: function(e, data) {
      if (exceedsMaxFiles(limit, fileInput, data)) return;
      var fileType = data.files[0].type;
      if (invalidFileType(fileType)) return;

      if (typeof addCallback !== 'undefined') addCallback();

      formData["Content-Type"] = fileType;
      data.formData = formData;

      // seed the AWS key with a random string here, not serverside, so each upload has a unique string
      if (formKey === '') formKey = data.formData.key;
      var pieces = formKey.split('$');
      var newKey = pieces[0] + randomString() + '_$' + pieces[1];
      data.formData.key = newKey;

      var uploader = $(this);
      data.process(function() {
        return uploader.fileupload('process', data);
      }).done(function() {
        data.submit();
      });
      fileInput.val('');
    },
    start: function() {
      submitButton.prop('disabled', true);
      if (typeof setLoadingIcon !== 'undefined') setLoadingIcon(fileInput);
    },
    done: function(e, data) {
      submitButton.prop('disabled', false);

      // extract key and generate URL from response
      var s3Key = $(data.jqXHR.responseXML).find("Key").text();
      var url = $(data.jqXHR.responseXML).find("Location").text();
      uploadedIcons[url] = s3Key;

      // Handled differently by different pages; handles UI and form updates
      addUploadedIcon(url, s3Key, data, fileInput);
    },
    fail: function(e, data) {
      submitButton.prop('disabled', false);
      if (typeof failCallback !== 'undefined') failCallback();
      unsetLoadingIcon();
      var response = data.response().jqXHR;
      var policyExpired = response.responseText.includes("Invalid according to Policy: Policy expired.");
      if (!policyExpired) policyExpired = response.responseText.includes("Idle connections will be closed.");
      var badFiletype = response.responseText.includes("Policy Condition failed") && response.responseText.includes('"$Content-Type", "image/"');
      var bugsData = {
        'response_status': response.status,
        'response_body': response.responseText,
        'response_text': response.statusText,
        'file_name': data.files[0].name,
        'file_type': data.files[0].type,
      };
      if (response.readyState === 0) {
        alert("Upload of " + data.files[0].name + " failed due to a network error. Please check your connection and try again.");
      } else if (policyExpired) {
        alert("Your upload permissions appear to have expired. Please refresh the page and try again.");
      } else if (badFiletype) {
        alert("You must upload files with an image filetype such as .png or .jpg - please retry with a valid file.");
      } else {
        $.post('/bugs', bugsData);
        alert("Upload of " + data.files[0].name + " failed, Marri has been notified.");
      }
    },
  };

  // If specified, limit number of files
  if (typeof form.data('limit') !== 'undefined')
    uploadArgs.maxNumberOfFiles = form.data('limit');

  fileInput.fileupload(uploadArgs);
}

function exceedsMaxFiles(limit, fileInput, data) {
  if (typeof limit === 'undefined' || limit <= 1) return false;

  var numUploading = fileInput[0].files.length;
  var isFirstFile = (fileInput[0].files[0] === data.files[0]);
  var isLastFile = (fileInput[0].files[numUploading - 1] === data.files[0]);

  return checkMaxFiles(limit, fileInput, isFirstFile, isLastFile);
}

function checkMaxFiles(limit, fileInput, isFirstFile, isLastFile) {
  var numUploading = fileInput[0].files.length;
  if (isFirstFile) numFiles += numUploading;
  if (numFiles <= limit) return false;

  if (isFirstFile) alert("You cannot upload more than "+limit+" files at once. Please try again.");
  if (isLastFile) {
    numFiles -= numUploading;
    fileInput.val(null);
  }
  return true;
}

function invalidFileType(fileType) {
  if (!fileType.startsWith('image/')) {
    alert("You must upload files with an image filetype such as .png or .jpg - please retry with a valid file.");
    unsetLoadingIcon();
    return true;
  } else if (fileType === 'image/tiff') {
    alert("Unfortunately, .tiff files are only supported by Safari - please retry with a valid file.");
    unsetLoadingIcon();
    return true;
  }
  return false;
}

function unsetLoadingIcon() {
  if ($(".loading-icon").length) $(".loading-icon").hide();
  if ($(".uploading-icon").length) $(".uploading-icon").show().removeClass('uploading-icon');
}

function deleteUnusedIcons(keys) {
  numFiles -= keys.length;
  $(keys).each(function(index, key) {
    $.authenticatedPost('/api/v1/icons/s3_delete', {s3_key: key});
  });
}
