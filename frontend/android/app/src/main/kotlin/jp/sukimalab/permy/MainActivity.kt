package jp.sukimalab.permy

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Parcelable
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
	private var eventSink: EventChannel.EventSink? = null
	private var initialSharePayload: Map<String, String?>? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"permy/share_receiver/methods",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getInitialSharePayload" -> {
					logInfo("method getInitialSharePayload payload=${initialSharePayload != null}")
					result.success(initialSharePayload)
				}
				"resetInitialSharePayload" -> {
					logInfo("method resetInitialSharePayload")
					initialSharePayload = null
					result.success(null)
				}

				else -> result.notImplemented()
			}
		}

		EventChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"permy/share_receiver/events",
		).setStreamHandler(this)

		initialSharePayload = buildSharePayload(intent)
		logInfo("configureFlutterEngine initialPayload=${initialSharePayload != null}")
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)

		val payload = buildSharePayload(intent) ?: return
		initialSharePayload = payload
		logInfo("onNewIntent payloadReady=true")
		eventSink?.success(payload)
	}

	override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
		eventSink = events
		logInfo("event channel listen")
	}

	override fun onCancel(arguments: Any?) {
		eventSink = null
		logInfo("event channel cancel")
	}

	private fun buildSharePayload(intent: Intent?): Map<String, String?>? {
		if (intent == null || intent.action != Intent.ACTION_SEND) {
			logInfo("buildSharePayload ignored action=${intent?.action ?: "null"}")
			return null
		}

		val mimeType = intent.type ?: return null
		if (!mimeType.startsWith("text/")) {
			logInfo("buildSharePayload ignored mimeType=$mimeType")
			return null
		}

		val hasExtraStream = intent.parcelableExtra<Uri>(Intent.EXTRA_STREAM) != null
		val clipItemCount = intent.clipData?.itemCount ?: 0
		val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
		logInfo(
			"buildSharePayload action=${intent.action} mimeType=$mimeType hasExtraStream=$hasExtraStream clipItems=$clipItemCount extraTextLooksUri=${extraText?.let(::looksLikeUri) == true}",
		)

		val uri = extractUri(intent)
		val text = readSharedText(intent, uri)?.trim().orEmpty()
		logInfo(
			"buildSharePayload extractedUri=${uri != null} uriScheme=${uri?.scheme ?: "null"} uriAuthority=${uri?.authority ?: "null"} textLength=${text.length}",
		)
		if (text.isEmpty()) {
			return null
		}

		return mapOf(
			"text" to text,
			"fileName" to resolveDisplayName(uri),
		)
	}

	private fun extractUri(intent: Intent): Uri? {
		val extraStream = intent.parcelableExtra<Uri>(Intent.EXTRA_STREAM)
		if (extraStream != null) {
			logInfo("extractUri source=extraStream")
			return extraStream
		}

		val clipData = intent.clipData
		if (clipData != null && clipData.itemCount > 0) {
			val item = clipData.getItemAt(0)
			item?.uri?.let {
				logInfo("extractUri source=clipData.uri")
				return it
			}

			val itemTextUri = item?.text
				?.toString()
				?.trim()
				?.takeIf(::looksLikeUri)
				?.let(Uri::parse)
			if (itemTextUri != null) {
				logInfo("extractUri source=clipData.text")
				return itemTextUri
			}
		}

		return intent.getStringExtra(Intent.EXTRA_TEXT)
			?.trim()
			?.takeIf(::looksLikeUri)
			?.let {
				logInfo("extractUri source=extraText")
				Uri.parse(it)
			}
	}

	private fun readSharedText(intent: Intent, uri: Uri?): String? {
		if (uri != null) {
			val bytes = applicationContext.contentResolver.openInputStream(uri)?.use { input ->
				val output = ByteArrayOutputStream()
				val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
				var total = 0

				while (true) {
					val read = input.read(buffer)
					if (read <= 0) {
						break
					}

					total += read
					if (total > MAX_SHARE_BYTES) {
						return null
					}

					output.write(buffer, 0, read)
				}

				output.toByteArray()
			} ?: return null

			logInfo("readSharedText source=uri bytes=${bytes.size}")

			return decodeText(bytes)
		}

		val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)
			?.takeUnless { looksLikeUri(it.trim()) }
		logInfo("readSharedText source=extraText textLength=${extraText?.length ?: 0}")
		return extraText
	}

	private fun decodeText(bytes: ByteArray): String? {
		val charsets = listOf(Charsets.UTF_8, Charset.forName("Shift_JIS"))
		for (charset in charsets) {
			try {
				val decoded = bytes.toString(charset)
				logInfo("decodeText charset=${charset.name()} textLength=${decoded.length}")
				return decoded
			} catch (_: Exception) {
			}
		}
		logInfo("decodeText failed")
		return null
	}

	private fun resolveDisplayName(uri: Uri?): String? {
		if (uri == null) {
			return null
		}

		var cursor: Cursor? = null
		try {
			cursor = applicationContext.contentResolver.query(
				uri,
				arrayOf(OpenableColumns.DISPLAY_NAME),
				null,
				null,
				null,
			)

			if (cursor != null && cursor.moveToFirst()) {
				val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
				if (index >= 0) {
					return cursor.getString(index)
				}
			}
		} finally {
			cursor?.close()
		}

		return uri.lastPathSegment?.substringAfterLast('/')
	}

	private inline fun <reified T : Parcelable> Intent.parcelableExtra(key: String): T? = when {
		Build.VERSION.SDK_INT >= 33 -> getParcelableExtra(key, T::class.java)
		else -> @Suppress("DEPRECATION") getParcelableExtra(key) as? T
	}

	private fun looksLikeUri(value: String): Boolean {
		return value.startsWith("content://") || value.startsWith("file://")
	}

	private fun logInfo(message: String) {
		Log.i(LOG_TAG, message)
	}

	private companion object {
		const val LOG_TAG = "PermyShare"
		const val MAX_SHARE_BYTES = 2 * 1024 * 1024
	}
}
