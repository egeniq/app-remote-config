package app.remote.config

import skip.lib.*

import skip.foundation.*

sealed class VersionRange {
    class EqualCase(val associated0: Version): VersionRange() {
    }
    class LesserThanCase(val associated0: Tuple2<Version, Boolean>): VersionRange() {
    }
    class GreaterThanCase(val associated0: Tuple2<Version, Boolean>): VersionRange() {
    }
    class BetweenCase(val associated0: Tuple2<Version, Boolean>, val associated1: Tuple2<Version, Boolean>): VersionRange() {
        val and = associated1
    }

    internal fun contains(other: Version): Boolean {
        return when (this) {
            is VersionRange.EqualCase -> {
                val version = this.associated0
                other == version
            }
            is VersionRange.LesserThanCase -> {
                val version = this.associated0
                if (version.element1) {
                    other <= version.element0
                } else {
                    other < version.element0
                }
            }
            is VersionRange.GreaterThanCase -> {
                val version = this.associated0
                if (version.element1) {
                    other >= version.element0
                } else {
                    other > version.element0
                }
            }
            is VersionRange.BetweenCase -> {
                val lower = this.associated0
                val upper = this.associated1
                when (Tuple2(lower.element1.sref(), upper.element1.sref())) {
                    Tuple2(false, false) -> other > lower.element0 && other < upper.element0
                    Tuple2(false, true) -> other > lower.element0 && other <= upper.element0
                    Tuple2(true, false) -> other >= lower.element0 && other < upper.element0
                    Tuple2(true, true) -> other >= lower.element0 && other <= upper.element0
                }
            }
        }
    }

    internal val rawValue: String
        get() {
            return when (this) {
                is VersionRange.EqualCase -> {
                    val version = this.associated0
                    version.rawValue
                }
                is VersionRange.LesserThanCase -> {
                    val version = this.associated0
                    if (version.element1) {
                        "<=${version.element0.rawValue}"
                    } else {
                        "<${version.element0.rawValue}"
                    }
                }
                is VersionRange.GreaterThanCase -> {
                    val version = this.associated0
                    if (version.element1) {
                        ">=${version.element0.rawValue}"
                    } else {
                        ">${version.element0.rawValue}"
                    }
                }
                is VersionRange.BetweenCase -> {
                    val lower = this.associated0
                    val upper = this.associated1
                    when (Tuple2(lower.element1.sref(), upper.element1.sref())) {
                        Tuple2(false, false) -> "${lower.element0.rawValue}>-<${upper.element0.rawValue}"
                        Tuple2(false, true) -> "${lower.element0.rawValue}>-${upper.element0.rawValue}"
                        Tuple2(true, false) -> "${lower.element0.rawValue}-<${upper.element0.rawValue}"
                        Tuple2(true, true) -> "${lower.element0.rawValue}-${upper.element0.rawValue}"
                    }
                }
            }
        }

    companion object {
        fun equal(associated0: Version): VersionRange = EqualCase(associated0)
        fun lesserThan(associated0: Tuple2<Version, Boolean>): VersionRange = LesserThanCase(associated0)
        fun greaterThan(associated0: Tuple2<Version, Boolean>): VersionRange = GreaterThanCase(associated0)
        fun between(associated0: Tuple2<Version, Boolean>, and: Tuple2<Version, Boolean>): VersionRange = BetweenCase(associated0, and)
    }
}

fun VersionRange(rawValue: String): VersionRange {
    val parts = rawValue
        .split(separator = '-')
        .map { it -> String(it) }
    if (parts.count == 2) {
        val lower = parts[0]
        val lowerIncluded = !lower.hasSuffix(">")
        val lowerVersion = Version(String(lower.dropLast(if (lowerIncluded) 0 else 1)))
        val upper = parts[1]
        val upperIncluded = !upper.hasPrefix("<")
        val upperVersion = Version(String(upper.dropFirst(if (upperIncluded) 0 else 1)))
        return VersionRange.between(Tuple2(lowerVersion.sref(), lowerIncluded), and = Tuple2(upperVersion.sref(), upperIncluded))
    } else if (parts.count == 1) {
        val part = parts[0]
        if (part.hasPrefix("<=") || part.hasPrefix("=<")) {
            val version = Version(String(part.dropFirst(2)))
            return VersionRange.lesserThan(Tuple2(version.sref(), true))
        } else if (part.hasPrefix("<")) {
            val version = Version(String(part.dropFirst(1)))
            return VersionRange.lesserThan(Tuple2(version.sref(), false))
        } else if (part.hasPrefix(">=") || part.hasPrefix("=>")) {
            val version = Version(String(part.dropFirst(2)))
            return VersionRange.greaterThan(Tuple2(version.sref(), true))
        } else if (part.hasPrefix(">")) {
            val version = Version(String(part.dropFirst(1)))
            return VersionRange.greaterThan(Tuple2(version.sref(), false))
        } else if (part.hasPrefix("=")) {
            val version = Version(String(part.dropFirst(1)))
            return VersionRange.equal(version)
        } else {
            val version = Version(String(part))
            return VersionRange.equal(version)
        }
    } else {
        throw ConfigError.invalidVersionRange
    }
}
