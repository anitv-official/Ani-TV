# Rhino's optional JSR-223 integration references javax.script, which is not
# provided by the Android runtime. CloudStream does not use that integration.
-dontwarn javax.script.**
