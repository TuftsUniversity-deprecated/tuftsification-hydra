	var initialVolume = 50; // not too loud by default or you'll drown out screen readers
	var seekInterval = 15; // number of seconds by which to seek forward or back
	var controllerId = 'controls'; // id of div for controls
	var controller;
	var playpauseButton;
	var stopButton;
	var seekBackwardButton;
	var seekForwardButton;
	var currentTimeContainer;
	var durationContainer;
	var muteButton;
	var volumeDownButton;
	var volumeUpButton;
	var fullScreenButton = null;

	function apiReadyHandler() {
		controller = document.getElementById(controllerId);

		playpauseButton = document.createElement('input');
		playpauseButton.setAttribute('type', 'button');
		playpauseButton.setAttribute('id', 'playpause');
		playpauseButton.setAttribute('value', '');
		playpauseButton.setAttribute('title', 'Play');
		playpauseButton.setAttribute('accesskey', 'P');
		controller.appendChild(playpauseButton);

		stopButton = document.createElement('input');
		stopButton.setAttribute('type', 'button');
		stopButton.setAttribute('id', 'stop');
		stopButton.setAttribute('value', '');
		stopButton.setAttribute('title', 'Stop');
		stopButton.setAttribute('accesskey', 'S');
		controller.appendChild(stopButton);

		seekBackwardButton = document.createElement('input');
		seekBackwardButton.setAttribute('type', 'button');
		seekBackwardButton.setAttribute('id', 'seekBack');
		seekBackwardButton.setAttribute('value', '');
		seekBackwardButton.setAttribute('title', 'Rewind ' + seekInterval + ' seconds');
		seekBackwardButton.setAttribute('accesskey', 'R');
		seekBackwardButton.disabled = true; // will be enabled after track begins to play
		seekBackwardButton.setAttribute('class', 'disabled');
		controller.appendChild(seekBackwardButton);

		seekForwardButton = document.createElement('input');
		seekForwardButton.setAttribute('type', 'button');
		seekForwardButton.setAttribute('id', 'seekForward');
		seekForwardButton.setAttribute('value', '');
		seekForwardButton.setAttribute('title', 'Forward ' + seekInterval + ' seconds');
		seekForwardButton.setAttribute('accesskey', 'F');
		seekForwardButton.disabled = true; // will be enabled after track begins to play
		seekForwardButton.setAttribute('class', 'disabled');
		controller.appendChild(seekForwardButton);

		var timer = document.createElement('span');
		timer.setAttribute('id', 'timer');
		currentTimeContainer = document.createElement('span');
		currentTimeContainer.setAttribute('id', 'currentTime');
		var startTime = document.createTextNode('0:00');
		currentTimeContainer.appendChild(startTime);

		durationContainer = document.createElement('span');
		durationContainer.setAttribute('id', 'duration');
		timer.appendChild(currentTimeContainer);
		timer.appendChild(durationContainer);
		controller.appendChild(timer);

		muteButton = document.createElement('input');
		muteButton.setAttribute('type', 'button');
		muteButton.setAttribute('id', 'mute');
		muteButton.setAttribute('value', '');
		muteButton.setAttribute('title', 'Mute');
		muteButton.setAttribute('accesskey', 'M');
		controller.appendChild(muteButton);

		volumeDownButton = document.createElement('input');
		volumeDownButton.setAttribute('type', 'button');
		volumeDownButton.setAttribute('id', 'volumeDown');
		volumeDownButton.setAttribute('value', '');
		volumeDownButton.setAttribute('title', 'Volume Down');
		volumeDownButton.setAttribute('accesskey', 'D');
		controller.appendChild(volumeDownButton);

		volumeUpButton = document.createElement('input');
		volumeUpButton.setAttribute('type', 'button');
		volumeUpButton.setAttribute('id', 'volumeUp');
		volumeUpButton.setAttribute('value', '');
		volumeUpButton.setAttribute('title', 'Volume Up');
		volumeUpButton.setAttribute('accesskey', 'U');
		controller.appendChild(volumeUpButton);

		// The following condition should be true for video, false for audio.
		if (jwplayer().getHeight() > 30 && jwplayer().getWidth() > 300) {
			// Move the volume controls to the left to make room for the fullscreen button.
			muteButton.style.left = '302px';
			volumeDownButton.style.left = '337px';
			volumeUpButton.style.left = '372px';

			// Make a divider between volume controls and fullscreen button
			volumeUpButton.style.borderRightColor = '#848484';

			// Add the fullscreen button
			fullScreenButton = document.createElement('input');
			fullScreenButton.setAttribute('type', 'button');
			fullScreenButton.setAttribute('id', 'fullScreen');
			fullScreenButton.setAttribute('value', '');
			fullScreenButton.setAttribute('title', 'Full-Screen');
			fullScreenButton.setAttribute('accesskey', 'B');  // B for Bigger;  F and S are already used.
			controller.appendChild(fullScreenButton);

			if (jwplayer().getRenderingMode() == 'flash') {
				// Hide our controls;  they are initally zIndex 1 so that they will be on top of the
				// JW Player (zIndex 0).  If JWP has fallen back to Flash because HTML 5 is not available (IE 8 and earlier),
				// our video controls' fullscreen button will not work (because the setFullscreen API method is
				// ignored due to concerns about phishing exploits), so we have to use JW Player's controls.
				// Our controls will still respond to access keys although the access key for fullscreen will be ignored.
				// For audio our controls will always be shown.
				controller.style.zIndex = -1;
			}
		}

		// Set default values
		jwplayer().setVolume(initialVolume);

		// Add listeners for JW Player events
		jwplayer().onPlay(onTrackStartHandler);
		jwplayer().onPause(onTrackPauseHandler);
		jwplayer().onIdle(onTrackIdleHandler);
		jwplayer().onBufferChange(onBufferedHandler);
		jwplayer().onTime(onProgressHandler);
		jwplayer().onComplete(onCompleteHandler);
		jwplayer().onMute(onMuteHandler);

		// Add listeners for control clicks
		if (document.addEventListener) {
			playpauseButton.addEventListener('click', togglePlaying, false);
			stopButton.addEventListener('click', stopPlaying, false);
			seekBackwardButton.addEventListener('click', seekBackward, false);
			seekForwardButton.addEventListener('click', seekForward, false);
			muteButton.addEventListener('click', toggleMute, false);
			volumeDownButton.addEventListener('click', volumeDown, false);
			volumeUpButton.addEventListener('click', volumeUp, false);
			if (fullScreenButton != null) fullScreenButton.addEventListener('click', toggleFullScreen, false);
		}
		else if (document.attachEvent) { // IE 8 and below
			playpauseButton.attachEvent('onclick', togglePlaying);
			stopButton.attachEvent('onclick', stopPlaying);
			seekBackwardButton.attachEvent('onclick', seekBackward);
			seekForwardButton.attachEvent('onclick', seekForward);
			muteButton.attachEvent('onclick', toggleMute);
			volumeDownButton.attachEvent('onclick', volumeDown);
			volumeUpButton.attachEvent('onclick', volumeUp);
			if (fullScreenButton != null) fullScreenButton.attachEvent('onclick', toggleFullScreen);
		}
	}

	function onTrackStartHandler() {
		playpauseButton.setAttribute('title', 'Pause');
		playpauseButton.style.backgroundImage = "url('/assets//media_player/media_player_pause.gif')";

		// Enable seek buttons
		seekBackwardButton.disabled = false;
		seekBackwardButton.removeAttribute('class');
		seekForwardButton.disabled = false;
		seekForwardButton.removeAttribute('class');
	}

	function onTrackPauseHandler() {
		playpauseButton.setAttribute('title', 'Play');
		playpauseButton.style.backgroundImage = "url('/assets/media_player/media_player_play.gif')";
	}

	function onTrackIdleHandler() {
		playpauseButton.setAttribute('title', 'Play');
		playpauseButton.style.backgroundImage = "url('/assets//media_player/media_player_play.gif')";

		// Disable seek buttons
		seekBackwardButton.disabled = true;
		seekBackwardButton.setAttribute('class', 'disabled');
		seekForwardButton.disabled = true;
		seekForwardButton.setAttribute('class', 'disabled');
	}

	function onBufferedHandler() {
		var duration = jwplayer().getDuration();

		if (duration < 0) duration = 0;

		showTime(duration, durationContainer);
	}

	function onProgressHandler() {
		var elapsedTime = jwplayer().getPosition();

		if (elapsedTime < 0) elapsedTime = 0;

		showTime(elapsedTime, currentTimeContainer);
	}

	function onCompleteHandler() {
		showTime(0, currentTimeContainer);
	}

	function onMuteHandler(event) {
		if (event.mute) {
			muteButton.setAttribute('title', 'UnMute');
			muteButton.style.backgroundImage = "url('/assets//media_player/media_player_mute.gif')";
		}
		else {
			muteButton.setAttribute('title', 'Mute');
			muteButton.style.backgroundImage = "url('/assets/media_player/media_player_volume.gif')";
		}
	}

	function togglePlaying() {
		jwplayer().play(); // play() with no argument toggles playing/paused state
	}

	function stopPlaying() {
		jwplayer().stop();

    // onComplete() callback does not appear to be invoked after stop().
		showTime(0, currentTimeContainer);
	}

	function seekBackward() {
		var trackPos = jwplayer().getPosition();
		var targetTime = Math.floor(trackPos - seekInterval);

		jwplayer().seek(targetTime);
	}

	function seekForward() {
		var trackPos = jwplayer().getPosition();
		var targetTime = Math.floor(trackPos + seekInterval);

		jwplayer().seek(targetTime);
	}

	function toggleMute() {
		jwplayer().setMute(); // setMute() with no argument toggles muted/unmuted state
	}

 	function volumeDown() {
		// volume is a range between 0 and 100
		var volume = jwplayer().getVolume();

    if (volume == 0) return;

		if (volume < 10) volume = 0;
		else volume -= 10;

		jwplayer().setVolume(volume);
	}

 	function volumeUp() {
		// volume is a range between 0 and 100
		var volume = jwplayer().getVolume();

    if (volume == 100) return;

		if (volume > 90) volume = 100;
		else volume += 10;			 

		jwplayer().setVolume(volume);
	}

	function toggleFullScreen() {
  		jwplayer().setFullscreen();  // This only works with HTML5, not with Flash.

			if (controller.style.zIndex == -1) {
				// Our accessible controls are hidden behind JW Player so the browser must be IE 8 and the full-screen
				// access key must have been touched, so JWP will be using flash but flash will ignore the setFullscreen()
				// API method.  Give the user a warning.
				alert("The full-screen access key does not work with Internet Explorer 8.  If you need to make the video full-screen from the keyboard you will have to upgrade to Internet Explorer 9 or later.");
			}
	}

	function showTime(time, elem) {
		if (elem == durationContainer && time == 0) {
			// duration is unknown;  don't display it
		}
		else {
			var minutes = Math.floor(time / 60);
			var seconds = Math.floor(time % 60);

			if (seconds < 10) seconds = '0' + seconds;

			var output = minutes + ':' + seconds;

			if (elem == currentTimeContainer) elem.innerHTML = output;
			else elem.innerHTML = ' / ' + output;
		}
	}

$(document).ready(
	function() {
    try {
  		jwplayer().onReady(apiReadyHandler);
    } catch (err) {
      console.log("No JWPlayer found on page.");
    }
	}
);
