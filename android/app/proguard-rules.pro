# Prevent R8 from crashing due to missing Push Provisioning classes (not used)
-dontwarn com.stripe.android.pushProvisioning.**

# Keep Stripe core classes
-keep class com.stripe.** { *; }
-dontwarn com.stripe.**
