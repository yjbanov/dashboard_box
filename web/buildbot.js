(function() {
  const url = 'https://build.chromium.org/p/client.flutter/json/builders/';

  function getBuildStatus(builderName) {
    var urlWithBuilder = url + builderName + '/';

    fetch(urlWithBuilder + 'builds').then(function(response){
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
      if (isSuccessful) {
        elem.classList.remove('buildbot-sad');
        elem.classList.add('buildbot-happy');
        document.body.classList.remove('build-broken');
      } else {
        elem.classList.remove('buildbot-happy');
        elem.classList.add('buildbot-sad');
        document.body.classList.add('build-broken');
      }
    }).catch(function(err) {
      console.error(err);
    });

    setTimeout(getBuildStatus, 5 * 60 * 1000);
  }

  getBuildStatus('Linux');
  getBuildStatus('Linux Engine');
  getBuildStatus('Mac');
  getBuildStatus('Mac Engine');
})();
