/* global gon */
var foundTags = {};

$(document).ready(function() {
  $(".chosen-select").select2({
    width: '100%',
    minimumResultsForSearch: 10,
  });

  $('.dropdown-toggle').dropdown();

  // Set localStorage if login status has changed
  // storage values are usually strings, cast to be sure
  var loggedInKey = 'loggedIn';
  if (window.gon) {
    var wasLoggedIn = gon.logged_in.toString();
    if (localStorage.getItem(loggedInKey) !== wasLoggedIn) {
      localStorage.setItem(loggedInKey, wasLoggedIn);
    }
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
  $("#"+formType+"_"+selector+"_ids").select2({
    tags: true,
    tokenSeparators: [','],
    placeholder: 'Enter ' + selector.replace('_', ' ') + '(s) separated by commas',
    ajax: {
      delay: 200,
      url: '/api/v1/tags',
      dataType: 'json',
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
      cache: true
    },
    createTag: function(params) {
      var term = $.trim(params.term);
      if (term === '') return null;
      var extantTag;
      foundTags[selector].forEach(function(tag) {
        if (tag.text.toUpperCase() === term.toUpperCase()) extantTag = tag;
      });
      if (extantTag) return extantTag;

      return {
        id: '_' + term,
        text: term
      };
    },
    width: '300px'
  });
}
