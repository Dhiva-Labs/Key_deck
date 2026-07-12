# mobile_scanner uses Google's unbundled ML Kit barcode scanner, whose
# components are discovered via reflection at runtime. R8 renaming/stripping
# them crashes the scanner in release builds with an NPE inside the plugin
# (seen as: "Attempt to invoke virtual method ... on a null object reference"
# from MethodChannel dev.steenbakker.mobile_scanner).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
