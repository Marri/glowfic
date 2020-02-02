/* global gon */
var foundTags = {};

$(document).ready(function() {
  createSelect2('.chosen-select', {
    minimumResultsForSearch: 10,
  });

  $(".flash-dismiss").click(function() {
    $(this).closest('.flash').slideUp(200);
    return false;
  });

  $("#select_all").click(function() {
    $(".select-all-box").prop('checked', this.checked);
  });

  // Set localStorage if login status has changed
  // storage values are usually strings, cast to be sure
  var loggedInKey = 'loggedIn';
  if (window.gon) {
    var wasLoggedIn = gon.logged_in.toString();
    if (localStorage.getItem(loggedInKey) !== wasLoggedIn) {
      localStorage.setItem(loggedInKey, wasLoggedIn);
    }
  }

  var oldPath = localStorage.getItem("tos.old_path");
  if (oldPath && location.pathname === oldPath && !location.hash) {
    location.hash = localStorage.getItem("tos.old_fragment");
    localStorage.removeItem("tos.old_path");
    localStorage.removeItem("tos.old_fragment");
  }

  // Watch for login status change
  // Display warning prompting user to reload when it occurs
  window.addEventListener('storage', function(e) {
    // skip non-login-status changes
    if (e.key !== loggedInKey) return;
    // skip creation and deletion of storage key (when someone loads the site for the first time or clears cache)
    if (e.oldValue === null || e.newValue === null) return;

    // find or create the warning box
    var warningBox = $('#login_status_warning');
    if (warningBox.length === 0) {
      warningBox = $('<div class="flash inbox pointer" id="login_status_warning">');
      warningBox.click(function() { $(this).remove(); });
      $('#header').after(warningBox);
    }

    // set the relevant warning text
    var msgText = 'logged ' + (e.newValue === 'true' ? 'in' : 'out');
    warningBox.html('You have <strong>' + msgText + '</strong> in another tab. Please reload before submitting any forms.');
  });
});

function addParameter(url, param, value) {
  var hash = {};
  var parser = document.createElement('a');

  parser.href = url;

  var parameters = parser.search.split(/\?|&/);

  for (var i=0; i < parameters.length; i++) {
    if (!parameters[i])
      continue;

    var ary = parameters[i].split('=');
    hash[ary[0]] = ary[1];
  }

  hash[param] = value;

  var list = [];
  Object.keys(hash).forEach(function(key) {
    list.push(key + '=' + hash[key]);
  });

  parser.search = '?' + list.join('&');
  return parser.href;
}

function resizeScreenname(screenameBox) {
  screenameBox = $(screenameBox);

  // reset previous CSS for post-editor screenname updates
  screenameBox.css('font-size', '');

  // shrink font-size to decrease box size
  if (screenameBox.height() <= 20) return;
  screenameBox.css('font-size', "87.5%");

  if (screenameBox.height() <= 20) return;
  screenameBox.css('font-size', "75%");
}

function saveExistingTags(selector, newTags) {
  var newList = foundTags[selector].concat(newTags);
  var ids = [];
  foundTags[selector] = [];
  // add tags, uniquely by ID
  newList.forEach(function(tag) {
    if (ids.indexOf(tag.id) >= 0) return;
    ids.push(tag.id);
    foundTags[selector].push(tag);
  });
}

function queryTransform(params) {
  var data = {
    q: params.term,
    page: params.page
  };
  return data;
}

function processResults(data, params, total, textKey) {
  params.page = params.page || 1;
  var processed = {
    results: data.results,
    pagination: {more: (params.page * 25) < total}
  };
  if (textKey) {
    // Reformat response data
    var formatted = [];
    for (var i=0; i < data.results.length; i++) {
      var result = data.results[i];
      formatted[i] = {
        id: result.id,
        text: result[textKey]
      };
    }
    processed.results = formatted;
  }
  return processed;
}

function createTagSelect(tagType, selector, formType, scope) {
  foundTags[selector] = [];

  createSelect2("#"+formType+"_"+selector+"_ids", {
    tags: true,
    tokenSeparators: [','],
    placeholder: 'Enter ' + selector.replace('_', ' ') + '(s) separated by commas',
    ajax: {
      url: '/api/v1/tags',
      data: function(params) {
        var data = queryTransform(params);
        data.t = tagType;
        if (scope) Object.assign(data, scope);
        return data;
      },
      processResults: function(data, params) {
        params.page = params.page || 1;
        var total = this._request.getResponseHeader('Total');
        var results = processResults(data, params, total);
        saveExistingTags(selector, data.results);
        return results;
      },
    },
    createTag: function(params) {
      var term = $.trim(params.term);
      if (term === '') return null;

      for (var i = 0; i < foundTags[selector].length; i++) {
        var tag = foundTags[selector][i];
        if (tag.text.toUpperCase() === term.toUpperCase()) return null;
      }

      return {
        id: '_' + term,
        text: term
      };
    },
    width: '300px'
  });
}

function createSelect2(selector, options) {
  if (!options.width) { options.width = '100%'; }
  if (options.ajax) addAjaxOptions(options);
  $(selector).select2(options);
}

function addAjaxOptions(options) {
  options.ajax.delay = 200;
  options.ajax.dataType = 'json';
  options.ajax.cache = true;
  if (gon.logged_in) options.ajax.headers = {'Authorization': 'Bearer '+gon.api_token};
  if (!options.ajax.data) { options.ajax.data = queryTransform; }
}

$.authenticatedGet = function(url, data, success, dataType) {
  return $.authenticatedAjax({
    url: url,
    data: data,
    success: success,
    dataType: dataType
  });
};

$.authenticatedPost = function(url, data, success, dataType) {
  return $.authenticatedAjax({
    url: url,
    data: data,
    success: success,
    dataType: dataType,
    type: "POST",
  });
};

$.authenticatedAjax = function(options) {
  if (gon.logged_in) options.headers = {'Authorization': 'Bearer '+gon.api_token};
  return $.ajax(options);
};
