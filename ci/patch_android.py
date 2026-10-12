"""Complète le projet Android généré par `flutter create` :
permissions, récepteurs de notifications, désucrage Java, icônes."""
import pathlib
import re
import shutil

root = pathlib.Path(__file__).resolve().parent.parent
android = root / "android"
app = android / "app"

# --- AndroidManifest.xml ---
manifest = app / "src/main/AndroidManifest.xml"
m = manifest.read_text()

permissions = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
"""
m = re.sub(r"(<manifest[^>]*>)", r"\1" + permissions, m, count=1)

receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
m = m.replace("</application>", receivers + "    </application>", 1)

queries = """
        <intent>
            <action android:name="android.media.action.IMAGE_CAPTURE" />
        </intent>
"""
if "<queries>" in m:
    m = m.replace("<queries>", "<queries>" + queries, 1)
else:
    m = m.replace("</manifest>", "    <queries>" + queries + "    </queries>\n</manifest>", 1)

m = re.sub(r'android:label="[^"]*"', 'android:label="Micky Quest"', m, count=1)
manifest.write_text(m)

# --- build.gradle de l'appli (Groovy ou Kotlin) ---
gradle = app / "build.gradle"
kts = app / "build.gradle.kts"
if gradle.exists():
    g = gradle.read_text()
    g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
    g = re.sub(r"minSdk\s*=?\s*flutter\.minSdkVersion", "minSdk = 24", g)
    g = re.sub(r"ndkVersion\s*=?\s*flutter\.ndkVersion", 'ndkVersion = "27.0.12077973"', g)
    # signature stable : toujours la même clé, pour pouvoir mettre à jour l'appli
    signing = '''
    signingConfigs {
        stable {
            storeFile file("${rootProject.projectDir}/../ci/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }

    buildTypes {'''
    g = re.sub(r"\n\s*buildTypes\s*\{", "\n" + signing, g, count=1)
    g = re.sub(r"signingConfig\s*=?\s*signingConfigs\.debug", "signingConfig = signingConfigs.stable", g)
    # pas de réduction R8 : elle cassait la programmation des notifications
    # (« Missing type parameter » dans flutter_local_notifications)
    g = g.replace("signingConfig = signingConfigs.stable", "signingConfig = signingConfigs.stable\n            minifyEnabled false\n            shrinkResources false", 1)
    if "signingConfigs.stable" not in g.split("signingConfigs {")[-1]:
        raise SystemExit("signature non configurée")
    g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    gradle.write_text(g)
elif kts.exists():
    g = kts.read_text()
    g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
    g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", g)
    g = re.sub(r"ndkVersion\s*=\s*flutter\.ndkVersion", 'ndkVersion = "27.0.12077973"', g)
    signing = '''
    signingConfigs {
        create("stable") {
            storeFile = file("${rootProject.projectDir}/../ci/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {'''
    g = re.sub(r"\n\s*buildTypes\s*\{", "\n" + signing, g, count=1)
    g = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("stable")', g)
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(g)
else:
    raise SystemExit("build.gradle introuvable")

# --- versions d'Android Gradle Plugin, Kotlin et Gradle ---
for name in ("settings.gradle", "settings.gradle.kts"):
    s = android / name
    if s.exists():
        t = s.read_text()
        t = re.sub(r'(id\(?\s*"com\.android\.application"\)?\s*version\s*)"[^"]+"', r'\1"8.7.3"', t)
        t = re.sub(r'(id\(?\s*"org\.jetbrains\.kotlin\.android"\)?\s*version\s*)"[^"]+"', r'\1"2.1.0"', t)
        s.write_text(t)

wrapper = android / "gradle/wrapper/gradle-wrapper.properties"
w = wrapper.read_text()
w = re.sub(r"distributionUrl=.*", r"distributionUrl=https\\://services.gradle.org/distributions/gradle-8.10.2-all.zip", w)
wrapper.write_text(w)

# --- règles ProGuard (au cas où la réduction serait réactivée) ---
(app / "proguard-rules.pro").write_text(
    "-keep class com.dexterous.** { *; }\n"
    "-keepattributes Signature\n"
    "-keepattributes *Annotation*\n"
    "-keep class com.google.gson.reflect.TypeToken { *; }\n"
    "-keep class * extends com.google.gson.reflect.TypeToken\n"
)

# --- icônes ---
for density in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
    dest = app / f"src/main/res/mipmap-{density}/ic_launcher.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(root / f"ci/icons/{density}.png", dest)

print("Projet Android complété.")
print(manifest.read_text())
print((gradle if gradle.exists() else kts).read_text())
