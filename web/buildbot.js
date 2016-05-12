// Globally visible list of current build statuses encoded as:
//
// {
//   "Mac": true,
//   "Linux": false
// }
var buildStatuses = {};

function allBuildsGreen() {
  var allGreen = true;
  for (var builderName in buildStatuses) {
    if (buildStatuses.hasOwnProperty(builderName)) {
      allGreen = allGreen && buildStatuses[builderName];
    }
  }
  return allGreen;
}

(function() {
  const url = 'https://build.chromium.org/p/client.flutter/json/builders/';

  function getBuildStatus(builderName) {
    var urlWithBuilder = url + builderName + '/';

    return fetch(urlWithBuilder + 'builds').then(function(response){
      if (response.status !== 200) {
        console.error('Error status listing builds: ' + response.status);
        return Promise.reject(new Error(response.statusText));
      }

      return response.json();
    }).then(function(data) {
      var keys = Object.keys(data);
      var latest = keys[keys.length-1];
      return Promise.resolve(latest);
    }).then(function(latestBuildNum) {
      return Promise.resolve(fetch(urlWithBuilder + 'builds/' + latestBuildNum));
    }).then(function(response) {
      if (response.status !== 200) {
        console.error('Error status retrieving build info: ' + response.status);
        return Promise.reject(new Error(response.statusText));
      }

      return response.json();
    }).then(function(data) {
      var isSuccessful = data['text'] && data['text'][1] === 'successful';
      var elem = document.querySelector('#buildbot-' + builderName.toLowerCase().replace(' ', '-') + '-status');
      buildStatuses[builderName] = isSuccessful;
      if (isSuccessful) {
        elem.classList.remove('buildbot-sad');
        elem.classList.add('buildbot-happy');
      } else {
        elem.classList.remove('buildbot-happy');
        elem.classList.add('buildbot-sad');
      }
    }).catch(function(err) {
      console.error(err);
    });
  }

  function getAllBuildStatuses() {
    Promise.all([
      getBuildStatus('Linux'),
      getBuildStatus('Linux Engine'),
      getBuildStatus('Mac'),
      getBuildStatus('Mac Engine')
    ]).then(function() {
      if (allBuildsGreen()) {
        document.body.classList.remove('build-broken');
      } else {
        document.body.classList.add('build-broken');
      }

      setTimeout(getAllBuildStatuses, 30 * 1000);
    }, function() {
      // Schedule a fetch even if the previous one fails, but wait a little longer
      setTimeout(getAllBuildStatuses, 60 * 1000);
    });
  }

  getAllBuildStatuses();
})();
