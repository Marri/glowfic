// orderBox is the box the ordering is scoped to
// so that a single page can have multiple separate ordering structures
function bindArrows(orderBox, path, param) {
  $(".section-up", orderBox).click(function() {
    var sourceRow = $(this).closest('.section-ordered');
    var targetRow = sourceRow.prev('.section-ordered');
    if (targetRow.length === 0) return false;
    swapRows(sourceRow, targetRow, orderBox, path, param);
    return false;
  }).addClass('pointer').removeClass('disabled-arrow');

  $(".section-down", orderBox).click(function() {
    var sourceRow = $(this).closest('.section-ordered');
    var targetRow = sourceRow.next('.section-ordered');
    if (targetRow.length === 0) return false;
    swapRows(sourceRow, targetRow, orderBox, path, param);
    return false;
  }).addClass('pointer').removeClass('disabled-arrow');

  $(".section-up", orderBox).first().addClass('disabled-arrow').removeClass('pointer');
  $(".section-down", orderBox).last().addClass('disabled-arrow').removeClass('pointer');
}

function unbindArrows(orderBox) {
  $(".section-down", orderBox).unbind().addClass('disabled-arrow').removeClass('pointer');
  $(".section-up", orderBox).unbind().addClass('disabled-arrow').removeClass('pointer');
}

function bindSortable(orderBox, path, param) {
  orderBox.addClass('sortableBox');
  var sortables = $(".sortable", orderBox);
  sortables.sortable({
    axis: 'y',
    cancel: '.section-warning',
    cursor: 'move',
    disable: true,
    handle: '.section-ordered-handle',
    opacity: 0.7,
    scroll: true,
    scrollSpeed: 10,
    tolerance: 'pointer',
    change: function() { reEvenOdd(orderBox); },
    update: function() { setToDisplayedOrder(orderBox, path, param); }
  });
  enableSortable(orderBox);
}

function enableSortable(orderBox) {
  if (!orderBox.hasClass('sortableBox')) return;
  $(".sortable", orderBox).sortable('enable');
  $(".section-ordered-handle img", orderBox).removeClass('disabled-arrow');
}

function disableSortable(orderBox) {
  if (!orderBox.hasClass('sortableBox')) return;
  $(".sortable", orderBox).sortable('disable');
  $(".section-ordered-handle img", orderBox).addClass('disabled-arrow');
}

function reEvenOdd(orderBox) {
  var flip = false;
  $("tr:not(.section-warning)", orderBox).each(function() {
    if (flip) $('td', this).removeClass('even').addClass('odd');
    else $('td', this).removeClass('odd').addClass('even');
    flip = !flip;
  });
  flip = false;
  $(".table-list li:not(.ui-sortable-helper)", orderBox).each(function() {
    if (flip) $(this).removeClass('even').addClass('odd');
    else $(this).removeClass('odd').addClass('even');
    flip = !flip;
  });
}

function reorderRows(orderBox) {
  var arrowBox = $('tbody, .table-list', orderBox);
  var rows = $('.section-ordered', arrowBox);
  var ordered = rows.sort(function(a, b) { return $(a).data('order') > $(b).data('order') ? 1 : -1; }).appendTo(arrowBox);
  reEvenOdd(orderBox);
  return ordered;
}

function swapRows(sourceRow, targetRow, orderBox, path, param) {
  var sourceOrder = sourceRow.data('order');
  var targetOrder = targetRow.data('order');
  sourceRow.data('order', targetOrder);
  targetRow.data('order', sourceOrder);
  syncRowOrders(orderBox, path, param);
}

function setToDisplayedOrder(orderBox, path, param) {
  var arrowBox = $('tbody, .table-list', orderBox);
  var rows = $('.section-ordered', arrowBox);
  rows.each(function(_, index) {
    $(this).data('order', index);
  });
  syncRowOrders(orderBox, path, param);
}

function getOrCreateWarningBox(orderBox) {
  var sectionWarning = $('.section-warning', orderBox);
  if (sectionWarning.length === 0) {
    if (orderBox.get(0).tagName.toUpperCase() === 'TABLE') {
      var outerBox = $("<tr>");
      sectionWarning = $("<td class='section-warning'>").appendTo(outerBox);
      orderBox.prepend(outerBox);
    } else {
      var aboveBox = $('.content-header', orderBox);
      sectionWarning = $("<div class='section-warning'>");
      aboveBox.after(sectionWarning);
    }
  }
  return sectionWarning;
}

function syncRowOrders(orderBox, path, param) {
  // Reduce race conditions by only allowing one update at a time
  unbindArrows(orderBox);
  disableSortable(orderBox);
  $("#loading", orderBox).show();
  $(".saveconf", orderBox).stop(true, true).hide();

  // Switch the row order pre-emptively
  var orderedRows = reorderRows(orderBox);

  // Figure out the full desired order and send it to the server
  var orderedIds = [];
  orderedRows.each(function() {
    orderedIds.push(parseInt($(this).data('id')));
  });
  var json = {};
  json['ordered_' + param] = orderedIds;
  // and restrict to relevant section_id if given
  if (window.gon && window.gon.section_id) json.section_id = window.gon.section_id;

  $.authenticatedPost(path, json, function(resp) {
    // Check the list doesn't have new elements, warn but don't block if it does
    if (orderedRows.length !== resp[param].length) {
      var sectionWarning = getOrCreateWarningBox(orderBox);
      sectionWarning.html('There are items missing from this list! Please reload.');
      console.log(resp.responseText);
    }

    // Set the full ordering according to the server response
    var returnedIds = resp[param];
    orderedRows.each(function() {
      var row = $(this);
      row.data('order', returnedIds.indexOf(row.data('id')));
    });
    reorderRows(orderBox);

    // Re-enable the buttons
    $("#loading", orderBox).hide();
    $(".saveconf", orderBox).show().delay(2000).fadeOut();
    bindArrows(orderBox, path, param);
    enableSortable(orderBox);
  }).fail(function(resp) {
    // Display an error and debug to console, warn and block
    $("#loading", orderBox).hide();
    $("#saveerror", orderBox).show();
    var sectionWarning = getOrCreateWarningBox(orderBox);
    var specificMessage = '';
    if (resp.status === 404) {
      specificMessage = 'One or more of the items could not be found. ';
    }
    sectionWarning.html('There was an error saving your changes! ' + specificMessage + 'Please reload. <em>(' + resp.status + ')</em>');
    console.log(resp.responseText);
  });
}
