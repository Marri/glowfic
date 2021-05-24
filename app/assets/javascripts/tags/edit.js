/* global createTagSelect */
$(document).ready(function() {
  var settingID = $("#setting_parent_setting_ids").data('setting-id');
  createTagSelect("Setting", "parent_setting", "setting", {setting_id: settingID});
});
