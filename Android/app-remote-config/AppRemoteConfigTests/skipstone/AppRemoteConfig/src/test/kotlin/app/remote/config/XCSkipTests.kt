package app.remote.config

import skip.lib.*

import skip.foundation.*

/// True when running in a transpiled Java runtime environment
internal val isJava = ProcessInfo.processInfo.environment["java.io.tmpdir"] != null
/// True when running within an Android environment (either an emulator or device)
internal val isAndroid = isJava && ProcessInfo.processInfo.environment["ANDROID_ROOT"] != null
/// True is the transpiled code is currently running in the local Robolectric test environment
internal val isRobolectric = isJava && !isAndroid
/// True if the system's `Int` type is 32-bit.
internal val is32BitInteger = Long(Int.max) == Long(Int.max)
