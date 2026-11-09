# wallet_verifier_api: keep rules applied to apps that use the plugin.
# Multipaz is a Kotlin Multiplatform library; keep it intact so R8 doesn't strip classes it
# reaches via ServiceLoader/reflection (crypto providers, serialization). Revisit to narrow.
-keep class org.multipaz.** { *; }
-keep class com.kiwis08.wallet_verifier_api.** { *; }
-dontwarn org.multipaz.**
-dontwarn org.bouncycastle.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.slf4j.**
-dontwarn io.ktor.**
