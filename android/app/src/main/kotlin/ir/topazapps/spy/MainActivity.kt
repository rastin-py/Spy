package ir.topazapps.spy

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.net.Uri
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Everything Spy asks of the phone, in one place. No third-party native code:
/// the app promises it never touches the network, and the cheapest way to keep
/// that promise honest is to own the small amount of platform code it needs.
class MainActivity : FlutterActivity() {

    /// One looping player for the tick. A player per tick leaks handles and
    /// drifts audibly within two minutes.
    private var tick: MediaPlayer? = null
    private var bell: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // FLAG_SECURE keeps a secret word out of screenshots and out of the
            // recents thumbnail. Handoff and Reveal only.
            "setSecure" -> {
                val secure = call.argument<Boolean>("secure") ?: false
                runOnUiThread {
                    if (secure) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
                result.success(null)
            }

            // Only ever used to decide whether to show the steel notice that
            // nobody will hear the clock.
            "isMuted" -> {
                val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val silenced = audio.ringerMode != AudioManager.RINGER_MODE_NORMAL
                val noVolume = audio.getStreamVolume(AudioManager.STREAM_MUSIC) == 0
                result.success(silenced || noVolume)
            }

            // Only while the clock runs and the setting is on; released on
            // pause, verdict, background and dispose alike.
            "setKeepAwake" -> {
                val awake = call.argument<Boolean>("awake") ?: false
                runOnUiThread {
                    if (awake) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                }
                result.success(null)
            }

            "storageDirectory" -> result.success(filesDir.absolutePath)

            // A store deep link, handed straight to the system. Spy never
            // installs anything; this only ever opens Bazaar on our page.
            "openUrl" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.success(false)
                    return
                }
                result.success(
                    try {
                        startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        true
                    } catch (error: ActivityNotFoundException) {
                        // No Bazaar, no browser, nothing that handles it. The
                        // banner stays where it is rather than claiming to
                        // have opened something.
                        false
                    }
                )
            }

            "startTicking" -> {
                val player = tick ?: create("assets/audio/tick.wav", looping = true)
                    ?.also { tick = it }
                player?.start()
                result.success(null)
            }

            "stopTicking" -> {
                tick?.let {
                    if (it.isPlaying) it.pause()
                    it.seekTo(0)
                }
                result.success(null)
            }

            "strikeBell" -> {
                val player = bell ?: create("assets/audio/bell.wav", looping = false)
                    ?.also { bell = it }
                player?.let {
                    it.seekTo(0)
                    it.start()
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /// Loads a sample straight out of the Flutter asset bundle.
    ///
    /// USAGE_MEDIA with the music stream is what makes the tick mix under the
    /// user's music and follow the media volume, rather than announcing itself
    /// as an alarm over the top of everything.
    private fun create(assetPath: String, looping: Boolean): MediaPlayer? {
        return try {
            val key = FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset(assetPath)
            val fd: AssetFileDescriptor = assets.openFd(key)
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                fd.use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                isLooping = looping
                setVolume(TICK_VOLUME, TICK_VOLUME)
                prepare()
            }
        } catch (error: Exception) {
            // No audio device, a broken codec, a missing asset: the game is
            // still completely playable, so this never reaches the player.
            null
        }
    }

    override fun onPause() {
        super.onPause()
        tick?.takeIf { it.isPlaying }?.pause()
    }

    override fun onDestroy() {
        tick?.release()
        bell?.release()
        tick = null
        bell = null
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "spy/platform"
        const val TICK_VOLUME = 0.55f
    }
}
