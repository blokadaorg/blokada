-dontwarn rx.internal.util.unsafe.**
-dontwarn nl.komponents.kovenant.unsafe.**

# Kodein
-keepattributes Signature

-keepclassmembers class **$WhenMappings {
    <fields>;
}

#-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
#    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
#}

# dnsjava
# See http://stackoverflow.com/questions/5701126
-optimizations !field/removal/writeonly,!field/marking/private,!class/merging/*,!code/allocation/variable
-dontnote org.xbill.DNS.spi.DNSJavaNameServiceDescriptor
-dontwarn org.xbill.DNS.spi.DNSJavaNameServiceDescriptor
-dontwarn sun.net.spi.nameservice.**

# pcap4j
-keep class org.slf4j.** { *; }
-keep class org.pcap4j.** { *; }
-dontwarn java.awt.*
-dontwarn org.slf4j.impl.StaticMDCBinder
-dontwarn org.slf4j.impl.StaticMarkerBinder
-dontwarn org.slf4j.impl.StaticLoggerBinder
-assumenosideeffects class org.slf4j.Logger {
    public void debug(...);
    public void trace(...);
}

# blokada
-keep class org.blokada.** { *; }

-keepclassmembers class * {
    private <fields>;
}
