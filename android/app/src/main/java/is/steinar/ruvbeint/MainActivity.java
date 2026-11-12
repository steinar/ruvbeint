package is.steinar.ruvbeint;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.TextView;

import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.PlayerView;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Opnar beint í beina útsendingu RÚV.
 *
 * Fjarstýring:
 *   Upp / Niður / Channel +/-  → skipta milli RÚV og RÚV 2
 *   OK / CC-takki              → kveikja/slökkva á íslenskum texta
 *   Til baka                   → loka
 */
public class MainActivity extends Activity {

    /** RÚV's own player API returns the current stream URL for each channel. */
    private static final String API = "https://geo.spilari.ruv.is/channel/";

    private static final String[] IDS = {"ruv", "ruv2"};
    private static final String[] NAMES = {"RÚV", "RÚV 2"};
    /** Used only if the API can't be reached. */
    private static final String[] FALLBACK = {
            "https://ruv-web-live.akamaized.net/streymi/ruverl/ruverl.m3u8",
            "https://ruvlive.akamaized.net/out/v1/2ff7673de40f419fa5164498fae89089/index.m3u8"
    };

    private static final long RETRY_MS = 5000;
    private static final long OSD_MS = 3000;

    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());

    private PlayerView playerView;
    private TextView status;
    private TextView osd;
    private ExoPlayer player;
    private SharedPreferences prefs;

    private int channel = 0;          // always start on RÚV
    private boolean subtitles;
    private int loadToken = 0;        // ignores stale lookups after channel switches

    private final Runnable hideOsd = () -> osd.setVisibility(View.GONE);
    private final Runnable retry = this::loadChannel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_main);
        playerView = findViewById(R.id.player_view);
        status = findViewById(R.id.status);
        osd = findViewById(R.id.osd);
        prefs = getSharedPreferences("ruvbeint", MODE_PRIVATE);
        subtitles = prefs.getBoolean("subtitles", false);
    }

    @Override
    protected void onStart() {
        super.onStart();
        hideSystemUi();
        player = new ExoPlayer.Builder(this).build();
        player.setPlayWhenReady(true);
        applySubtitles();
        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int state) {
                if (state == Player.STATE_READY) status.setVisibility(View.GONE);
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
                    player.seekToDefaultPosition();
                    player.prepare();
                    return;
                }
                showStatus("Næ ekki sambandi við " + NAMES[channel] + ".\nReyni aftur…");
                main.removeCallbacks(retry);
                main.postDelayed(retry, RETRY_MS);
            }
        });
        playerView.setPlayer(player);
        loadChannel();
    }

    @Override
    protected void onStop() {
        super.onStop();
        main.removeCallbacks(retry);
        loadToken++;
        if (player != null) {
            playerView.setPlayer(null);
            player.release();
            player = null;
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        io.shutdownNow();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) hideSystemUi();
    }

    private void loadChannel() {
        if (player == null) return;
        final int token = ++loadToken;
        final int ch = channel;
        if (player.getPlaybackState() != Player.STATE_READY) {
            showStatus("Tengist " + NAMES[ch] + "…");
        }
        io.execute(() -> {
            String url = resolveUrl(IDS[ch]);
            if (url == null) url = FALLBACK[ch];
            final String streamUrl = url;
            main.post(() -> {
                if (player == null || token != loadToken) return;
                MediaItem item = new MediaItem.Builder()
                        .setUri(streamUrl)
                        .setMimeType(MimeTypes.APPLICATION_M3U8)
                        .build();
                player.setMediaItem(item);
                player.prepare();
                player.play();
            });
        });
    }

    /** Asks RÚV's player API for the channel's current stream URL. */
    private static String resolveUrl(String id) {
        HttpURLConnection conn = null;
        try {
            conn = (HttpURLConnection) new URL(API + id).openConnection();
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);
            if (conn.getResponseCode() != 200) return null;
            StringBuilder sb = new StringBuilder();
            try (BufferedReader r = new BufferedReader(
                    new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) sb.append(line);
            }
            String url = new JSONObject(sb.toString()).optString("url", "");
            return url.startsWith("http") ? url : null;
        } catch (Exception e) {
            return null;
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private void switchChannel(int delta) {
        channel = (channel + delta + IDS.length) % IDS.length;
        main.removeCallbacks(retry);
        if (player != null) player.stop();
        showOsd(NAMES[channel]);
        showStatus("Tengist " + NAMES[channel] + "…");
        loadChannel();
    }

    private void toggleSubtitles() {
        subtitles = !subtitles;
        prefs.edit().putBoolean("subtitles", subtitles).apply();
        applySubtitles();
        showOsd(subtitles ? "Texti: Á" : "Texti: AF");
    }

    private void applySubtitles() {
        if (player == null) return;
        player.setTrackSelectionParameters(player.getTrackSelectionParameters()
                .buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, !subtitles)
                .setPreferredTextLanguage("is")
                .build());
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_CHANNEL_UP:
                switchChannel(1);
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
            case KeyEvent.KEYCODE_CHANNEL_DOWN:
                switchChannel(-1);
                return true;
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_CAPTIONS:
                toggleSubtitles();
                return true;
            case KeyEvent.KEYCODE_DPAD_LEFT:
            case KeyEvent.KEYCODE_DPAD_RIGHT:
            case KeyEvent.KEYCODE_INFO:
                showOsd(NAMES[channel] + "  ·  " + (subtitles ? "texti á" : "texti af"));
                return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    private void showStatus(String text) {
        status.setText(text);
        status.setVisibility(View.VISIBLE);
    }

    private void showOsd(String text) {
        osd.setText(text);
        osd.setVisibility(View.VISIBLE);
        main.removeCallbacks(hideOsd);
        main.postDelayed(hideOsd, OSD_MS);
    }

    @SuppressWarnings("deprecation")
    private void hideSystemUi() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }
}
