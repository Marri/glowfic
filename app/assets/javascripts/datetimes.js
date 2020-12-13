/* global gon */
var options = {
  dateStyle: 'medium',
  timeStyle: 'short',
};
var format = Intl.DateTimeFormat('en-US', options);

window.onload = function() {
  if (gon.logged_in) return;
  var times = document.getElementsByTagName('time');
  Array.from(times).forEach(function(time) {
    var datetime = new Date(time.dateTime);
    time.innerText = format.format(datetime);
  });
};
