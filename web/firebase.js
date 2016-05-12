(function() {
  var ref = new Firebase("https://purple-butterfly-3000.firebaseio.com/");
  ref.onAuth(authDataCallback);

  function authDataCallback(authData) {
    if (authData) {
      console.log("User " + authData.uid + " is logged in with " +
        authData.provider + " and has displayName '" +
        authData.google.displayName + "' and email " + authData.google.email);
      // Save the user's profile into the database so we can
      // use them in Security and Firebase Rules.
      // We don't trust this data, so don't rely on the email.
      ref.child("users").child(authData.uid).set({
        provider: authData.provider,
        name: authData.google.displayName,
        email: authData.google.email || 'undefined'
      }).then(function(snapshot) {
        getData();
      }, function(error) {
        console.error(error);
      });
    } else {
      console.log("User is logged out");
    }
  }

  function authHandler(error, authData) {
    if (error) {
      console.log("Login Failed!", error);
    } else {
      console.log("Authenticated successfully with payload:", authData);
    }
  }

  function getData() {
    ref.child('measurements').on("value", function(snapshot) {
      removeExistingBoxes();
      generateBoxes(snapshot.val());
      updateLastJobRanTime(snapshot.child('build').child('current').val());
    }, function (errorObject) {
      console.log("The read failed: " + errorObject.code);
    });
  }

  function removeExistingBoxes() {
    var boxesFromFirebase = document.querySelectorAll('.from-firebase');
    Array.prototype.forEach.call(boxesFromFirebase, function (box) {
      box.parentNode.removeChild(box);
    });
  }

  function _cloneTemplate(measurementType) {
    var tmplId = '#' + measurementType + '_tmpl';
    var tmpl = document.querySelector(tmplId);
    if (tmpl == undefined) {
      console.error('Template for ' + tmplId + ' not found');
      return null;
    }
    var clone = document.importNode(tmpl.content, true);
    return clone;
  }

  function _getTitleForTemplate(measurementType, measurementName) {
    return measurementName.substring(0, measurementName.length-measurementType.length);
  }

  function _parseHtml(string) {
    var div = document.createElement('div');
    div.innerHTML = string;
    return div.firstChild;
  }

  function _comma(str) {
    if (str.length > 3)
      str = str.substring(0, str.length - 3) + ',' + str.substring(str.length - 3);
    return str;
  }

  var generators = {
    '__analysis_time': function(measurementType, measurementName, data) {
      var clone = _cloneTemplate(measurementType);
      if (clone == null) return;
      var title = _getTitleForTemplate(measurementType, measurementName);
      var targetPercent = Math.round((data.expected / data.time) * 100);

      clone.querySelector('.metric-number').textContent = parseFloat(data.time).toFixed(1);
      clone.querySelector('.metric-name').textContent = title;
      clone.querySelector('.metric-target').textContent = data.expected.toFixed(1);
      document.querySelector('#container').appendChild(clone);
    },

    '__refresh_time': function(measurementType, measurementName, data) {
      var clone = _cloneTemplate(measurementType);
      if (clone == null) return;
      var title = _getTitleForTemplate(measurementType, measurementName);
      var targetPercent = Math.round((data.expected / data.time) * 100);

      clone.querySelector('.metric-number').textContent = _comma(data.time.toString());
      clone.querySelector('.metric-name').textContent = title;
      clone.querySelector('.metric-target').textContent = data.expected;
      document.querySelector('#container').appendChild(clone);
    },

    '__start_up': function(measurementType, measurementName, data) {
      var clone = _cloneTemplate(measurementType);
      if (clone == null) return;
      var title = _getTitleForTemplate(measurementType, measurementName);
      clone.querySelector('.metric-name').textContent = title;
      var timeToFirstFrame = _comma((data.timeToFirstFrameMicros / 1000).toFixed(0));
      clone.querySelector('.metric-number').textContent = timeToFirstFrame;
      clone.querySelector('.time-to-framework-init').textContent = _comma((data.timeToFrameworkInitMicros / 1000).toFixed(0));
      clone.querySelector('.time-after-init-to-first-frame').textContent = _comma((data.timeAfterFrameworkInitMicros / 1000).toFixed(0));

      document.querySelector('#container').appendChild(clone);
    },

    '__timeline_summary': function(measurementType, measurementName, data) {
      var clone = _cloneTemplate(measurementType);
      if (clone == null) return;
      var title = _getTitleForTemplate(measurementType, measurementName);
      if (title.endsWith('_scroll_perf'))
        title = title.substring(0, title.length - '_scroll_perf'.length)
      clone.querySelector('.metric-name').textContent = title;
      clone.querySelector('.average_frame_build_time_millis').textContent = data.average_frame_build_time_millis.toFixed(2);
      clone.querySelector('.frame_count').textContent = data.frame_count;
      clone.querySelector('.metric-number').textContent = data.missed_frame_build_budget_count;

      if (data.missed_frame_build_budget_count > 0) {
        clone.querySelector('.metric-section').appendChild(
          _parseHtml('<span><span class="warning metric">' + data.missed_frame_build_budget_count + ' missed</span></span>')
        );
      }

      var framesContainer = clone.querySelector('.frames');
      data.frame_build_times.forEach(function (frameBuildTime) {
        var div;
        if (frameBuildTime > 24000) {
          div = _parseHtml('<div class="terrible-frame frame" style="height: ' + (24000 / 200) + 'px"></div>');
        } else if (frameBuildTime > 8000) {
          div = _parseHtml('<div class="bad-frame frame" style="height: ' + (frameBuildTime / 200) + 'px"></div>');
        } else {
          div = _parseHtml('<div class="good-frame frame" style="height: ' + (frameBuildTime / 200) + 'px"></div>');
        }
        framesContainer.appendChild(div);
      });

      document.querySelector('#container').appendChild(clone);
    }
  };

  var ignoredMeasurements = [
    'build',
    'stocks__start_up'
  ];

  function updateLastJobRanTime(buildData) {
    var lastJobRanTime = document.querySelector('#last-job-ran-time');
    var eightHoursInMillis = 8 * 3600 * 1000;
    var buildAge = Date.now() - Date.parse(buildData.build_timestamp);
    var buildOutOfDateLabel = document.querySelector('#build-out-of-date');
    if (allBuildsGreen() && buildAge > eightHoursInMillis) {
      buildOutOfDateLabel.style.display = 'block';
    } else {
      buildOutOfDateLabel.style.display = 'none';
    }

    if (lastJobRanTime) {
      lastJobRanTime.textContent = buildData.build_timestamp;
    }
  }

  function generateBoxes(measurements) {
    for (var measurementName in measurements) {
      if (measurements.hasOwnProperty(measurementName) && ignoredMeasurements.indexOf(measurementName) != 0) {
        var measurementType = measurementName
            .substring(measurementName.indexOf('__'), measurementName.length);
        var generator = generators[measurementType];
        if (generator === undefined) {
          console.error('Did not find generator for ' + measurementName +
              ' of type ' + measurementType);
          continue;
        }
        generator(measurementType, measurementName, measurements[measurementName]['current']);
      }
    }

    updateLastUpdatedTime();
  }

  function updateLastUpdatedTime() {
    document.querySelector('#firebase-last-updated-time').textContent = new Date();
  }

  document.getElementById('firebase-login').addEventListener('click', function() {
    ref.authWithOAuthPopup("google", authHandler, {'scope': "email"});
  });

  document.getElementById('firebase-logout').addEventListener('click', function() {
    console.log('Logging out');
    ref.unauth();
  });
})();
