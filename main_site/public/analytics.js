gapi.analytics.ready(function() {

  var CLIENT_ID = '308150028417-ftb1c29on9s56ans77e1ani24a8b6m10.apps.googleusercontent.com';

  gapi.analytics.auth.authorize({
    container: 'auth-button',
    clientid: CLIENT_ID,
  });

  var viewSelector = new gapi.analytics.ViewSelector({
    container: 'view-selector'
  });

  var timeline = new gapi.analytics.googleCharts.DataChart({
    reportType: 'ga',
    query: {
      'dimensions': 'ga:date',
      'metrics': 'ga:7dayUsers',
      'start-date': '30daysAgo',
      'end-date': 'yesterday',
      'ids': 'ga:120928408'
    },
    chart: {
      type: 'LINE',
      container: '7da-timeline'
    }
  });

  timeline.on('success', function(response) {
    var rows = response.data.rows;
    var lastActiveUserCount = rows[rows.length-1]['c'][1]['v'];
    document.getElementById('num-7da').innerHTML = lastActiveUserCount;
  });

  timeline.execute();

});