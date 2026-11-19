# Sourced by the build scripts. With only the Command Line Tools installed (no Xcode),
# the newest SDK's SwiftUI macros (@State) and swift-testing's macros aren't on the
# default plugin path, so pick a compatible SDK and point at the testing plugin.
CLT=/Library/Developer/CommandLineTools
if ! xcode-select -p 2>/dev/null | grep -q "Xcode"; then
    if [ -z "${SDKROOT:-}" ]; then
        for sdk in "$CLT"/SDKs/MacOSX26.5.sdk "$CLT"/SDKs/MacOSX26.sdk; do
            if [ -d "$sdk" ]; then export SDKROOT="$sdk"; break; fi
        done
    fi
    if [ -d "$CLT/usr/lib/swift/host/plugins/testing" ]; then
        TEST_FLAGS="-Xswiftc -plugin-path -Xswiftc $CLT/usr/lib/swift/host/plugins/testing"
    fi
fi
TEST_FLAGS="${TEST_FLAGS:-}"
