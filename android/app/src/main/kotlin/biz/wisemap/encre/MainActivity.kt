package biz.wisemap.encre

import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val updateManager = AppUpdateManagerFactory.create(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "biz.wisemap.encre/app_update"
        ).setMethodCallHandler { call, result ->
            if (call.method != "isUpdateAvailable") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            updateManager.appUpdateInfo
                .addOnSuccessListener { info ->
                    result.success(info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE)
                }
                .addOnFailureListener { result.success(false) }
        }
    }
}
