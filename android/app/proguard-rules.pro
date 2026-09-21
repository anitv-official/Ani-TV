# Rhino's optional JSR-223 integration references javax.script, which is not
# provided by the Android runtime. CloudStream does not use that integration.
-dontwarn javax.script.**

# Rhino's optional Java bean conversion support references java.beans, which is
# also absent from the Android runtime and is not used by CloudStream.
-dontwarn java.beans.**
