package app.remote.config

import skip.lib.*

import skip.foundation.*

sealed class ConfigError: Exception(), Error {
    class NonSemanticVersionCase: ConfigError() {
    }
    class InvalidVersionRangeCase: ConfigError() {
    }
    class UnexpectedTypeForKeyCase(val associated0: String): ConfigError() {
    }

    companion object {
        val nonSemanticVersion: ConfigError
            get() = NonSemanticVersionCase()
        val invalidVersionRange: ConfigError
            get() = InvalidVersionRangeCase()
        fun unexpectedTypeForKey(associated0: String): ConfigError = UnexpectedTypeForKeyCase(associated0)
    }
}
