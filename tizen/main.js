// RÚV Beint fyrir Samsung Tizen.
// Upp/niður eða CH+/CH−: RÚV ↔ RÚV 2.  OK: texti á/af.  Til baka: loka.
(function () {
  var API = 'https://geo.spilari.ruv.is/channel/';
  var CH = [
    { id: 'ruv',  name: 'RÚV',   fb: 'https://ruv-web-live.akamaized.net/streymi/ruverl/ruverl.m3u8' },
    { id: 'ruv2', name: 'RÚV 2', fb: 'https://ruvlive.akamaized.net/out/v1/2ff7673de40f419fa5164498fae89089/index.m3u8' }
  ];
  var cur = 0, token = 0, retryTimer = null, osdTimer = null;
  var subs = false;
  try { subs = localStorage.getItem('subs') === '1'; } catch (e) {}

  var statusEl = document.getElementById('status');
  var osdEl = document.getElementById('osd');
  var av = window.webapis && webapis.avplay;

  function status(t) { statusEl.textContent = t; statusEl.style.display = t ? 'flex' : 'none'; }
  function osd(t) {
    osdEl.textContent = t; osdEl.style.display = 'block';
    clearTimeout(osdTimer); osdTimer = setTimeout(function () { osdEl.style.display = 'none'; }, 3000);
  }

  function resolve(ch, cb) {
    var done = false, x = new XMLHttpRequest();
    var finish = function (u) { if (!done) { done = true; cb(u || ch.fb); } };
    x.open('GET', API + ch.id); x.timeout = 5000;
    x.onload = function () {
      try { var j = JSON.parse(x.responseText); finish(/^https?:/.test(j.url) ? j.url : null); }
      catch (e) { finish(null); }
    };
    x.onerror = x.ontimeout = function () { finish(null); };
    x.send();
  }

  function scheduleRetry() {
    status('Næ ekki sambandi við ' + CH[cur].name + '.\nReyni aftur…');
    clearTimeout(retryTimer); retryTimer = setTimeout(load, 5000);
  }

  function applySubs() {
    try {
      var tracks = av.getTotalTrackInfo(), textIdx = -1;
      for (var i = 0; i < tracks.length; i++) if (tracks[i].type === 'TEXT') { textIdx = tracks[i].index; break; }
      if (textIdx >= 0) av.setSelectTrack('TEXT', textIdx);
      av.setSilentSubtitle(!subs);
    } catch (e) {}
  }

  function stop() { try { av.stop(); } catch (e) {} try { av.close(); } catch (e) {} }

  function load() {
    var my = ++token, ch = CH[cur];
    clearTimeout(retryTimer);
    status('Tengist ' + ch.name + '…');
    resolve(ch, function (url) {
      if (my !== token) return;
      stop();
      try {
        av.open(url);
        av.setDisplayRect(0, 0, 1920, 1080);
        av.setDisplayMethod('PLAYER_DISPLAY_MODE_LETTER_BOX');
        av.setStreamingProperty('ADAPTIVE_INFO', 'FIXED_MAX_RESOLUTION=1920x1080');
        av.setListener({
          onbufferingstart: function () {},
          onbufferingcomplete: function () { if (my === token) status(''); },
          onstreamcompleted: function () { if (my === token) scheduleRetry(); },
          onerror: function () { if (my === token) scheduleRetry(); },
          onevent: function () {},
          onsubtitlechange: function () {}
        });
        av.prepareAsync(function () {
          if (my !== token) return;
          applySubs(); av.play(); status('');
        }, function () { if (my === token) scheduleRetry(); });
      } catch (e) { scheduleRetry(); }
    });
  }

  function switchCh(d) { cur = (cur + d + CH.length) % CH.length; osd(CH[cur].name); load(); }

  try {
    ['ChannelUp', 'ChannelDown', 'Info', 'Caption'].forEach(function (k) {
      try { tizen.tvinputdevice.registerKey(k); } catch (e) {}
    });
  } catch (e) {}

  document.addEventListener('keydown', function (e) {
    switch (e.keyCode) {
      case 38: case 427: switchCh(1); break;              // Up, ChannelUp
      case 40: case 428: switchCh(-1); break;             // Down, ChannelDown
      case 13: case 10221:                                 // Enter, Caption
        subs = !subs;
        try { localStorage.setItem('subs', subs ? '1' : '0'); } catch (x) {}
        applySubs(); osd(subs ? 'Texti: Á' : 'Texti: AF'); break;
      case 37: case 39: case 457:                          // Left, Right, Info
        osd(CH[cur].name + '  ·  ' + (subs ? 'texti á' : 'texti af')); break;
      case 10009:                                          // Back
        stop(); try { tizen.application.getCurrentApplication().exit(); } catch (x) {} break;
    }
  });

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { token++; stop(); } else { load(); }
  });

  if (!av) { status('AVPlay vantar – keyrðu á Samsung TV.'); return; }
  load();
})();
