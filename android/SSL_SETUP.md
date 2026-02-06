# Fixing SSL / PKIX errors when building Android (corporate proxy)

If you see `SSLHandshakeException: PKIX path building failed` or `unable to find valid certification path to requested target`, your network is likely using a corporate proxy that does SSL inspection. Java does not trust the proxy’s certificate by default.

Use **one** of the approaches below.

---

## Option 1: Trust your corporate CA in Java (recommended)

1. **Get your corporate root CA certificate**
   - From your IT team, or  
   - In Chrome: open https://services.gradle.org → padlock → Certificate → Details → copy the **root** CA (e.g. “Company Root CA”) and export as PEM/CRT.

2. **Import it into Java’s truststore** (use your JDK path; `java -XshowSettings:properties` shows `java.home`):

   ```bash
   # Replace /path/to/jdk and /path/to/corp-root.crt with your paths
   keytool -importcert -alias corp-root-ca -file /path/to/corp-root.crt \
     -keystore "$(java -XshowSettings:properties -version 2>&1 | grep 'java.home' | sed 's/.*= *//')/lib/security/cacerts" \
     -storepass changeit -noprompt
   ```

3. Run the Android build again:

   ```bash
   npx react-native run-android
   ```

---

## Option 2: Use a local Gradle distribution (no HTTPS from Java)

If you can’t change the Java truststore, use a pre-downloaded Gradle zip so the wrapper doesn’t need to download over HTTPS.

1. **Download the Gradle zip from a network that works** (e.g. home Wi‑Fi or phone hotspot, or another machine):
   - https://services.gradle.org/distributions/gradle-8.0.1-all.zip  
   - Save it as:  
     `android/gradle/wrapper/gradle-8.0.1-all.zip`

2. **Point the wrapper at the local file** in `android/gradle/wrapper/gradle-wrapper.properties`:

   Replace the `distributionUrl` line with (use your real project path):

   ```properties
   distributionUrl=file\:///Users/YOUR_USERNAME/Documents/tracker-poc/TrackerApp72/android/gradle/wrapper/gradle-8.0.1-all.zip
   ```

   For user `aditya.sray`:

   ```properties
   distributionUrl=file\:///Users/aditya.sray/Documents/tracker-poc/TrackerApp72/android/gradle/wrapper/gradle-8.0.1-all.zip
   ```

3. Run the build again:

   ```bash
   npx react-native run-android
   ```

---

## Option 3: Custom truststore (keep Java default cacerts unchanged)

1. Create a copy of the default cacerts and add your corporate CA:

   ```bash
   cp "$(java -XshowSettings:properties -version 2>&1 | grep 'java.home' | sed 's/.*= *//')/lib/security/cacerts" ./android-cacerts
   keytool -importcert -alias corp-root-ca -file /path/to/corp-root.crt \
     -keystore ./android-cacerts -storepass changeit -noprompt
   ```

2. Run Gradle with that truststore:

   ```bash
   export GRADLE_OPTS="-Djavax.net.ssl.trustStore=$(pwd)/android-cacerts -Djavax.net.ssl.trustStorePassword=changeit"
   cd android && ./gradlew assembleDebug
   ```

   Or set `org.gradle.jvmargs` in `android/gradle.properties` to include the same `-Djavax.net.ssl.trustStore=...` and `-Djavax.net.ssl.trustStorePassword=...` (and keep `-Xmx2048m` etc.).

After the first successful build, later builds may only need to download dependencies; if those also fail with SSL, the same CA must be trusted (Options 1 or 3).
