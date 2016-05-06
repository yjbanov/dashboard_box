(function () {
  var TWO_HOURS = 2 * 60 * 60 * 1000;
  setTimeout(TWO_HOURS, function() {
    document.location.reload(true);
  });
})();