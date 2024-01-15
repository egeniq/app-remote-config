package app.remote.config

import skip.lib.*
import skip.lib.Array

import skip.foundation.*

class Version: Comparable<Version>, MutableStruct {
    override fun compareTo(other: Version): Int {
        if (this == other) return 0
        fun islessthan(lhs: Version, rhs: Version): Boolean {
            return if (lhs.canonical.element0 == rhs.canonical.element0 && lhs.canonical.element1 == rhs.canonical.element1) {
                lhs.canonical.element2 < rhs.canonical.element2
            } else if (lhs.canonical.element0 == rhs.canonical.element0) {
                lhs.canonical.element1 < rhs.canonical.element1
            } else {
                lhs.canonical.element0 < rhs.canonical.element0
            }
        }
        return if (islessthan(this, other)) -1 else 1
    }

    override fun equals(other: Any?): Boolean {
        if (other !is Version) {
            return false
        }
        val lhs = this
        val rhs = other
        return lhs.canonical.element0 == rhs.canonical.element0 && lhs.canonical.element1 == rhs.canonical.element1 && lhs.canonical.element2 == rhs.canonical.element2
    }

    internal var canonical: Tuple3<Int, Int, Int>
        set(newValue) {
            willmutate()
            field = newValue
            didmutate()
        }

    val rawValue: String
        get() = "${canonical.element0}.${canonical.element1}.${canonical.element2}"

    constructor(rawValue: String) {
        var trimmedValue = rawValue
        trimmedValue
            .trimPrefix(while_ = { it -> !"1234567890.".contains(it) })
        val parts = trimmedValue
            .split(separator = '.')
            .compactMap { it -> Int(it) }
            .prefix(3)
        if (parts.count < 1) {
            throw ConfigError.nonSemanticVersion
        }
        val padded = (parts + Array(repeating = 0, count = max(3 - parts.count, 0))).sref()
        canonical = Tuple3(padded[0].sref(), padded[1].sref(), padded[2].sref())
    }

    private constructor(copy: MutableStruct) {
        @Suppress("NAME_SHADOWING", "UNCHECKED_CAST") val copy = copy as Version
        this.canonical = copy.canonical
    }

    override var supdate: ((Any) -> Unit)? = null
    override var smutatingcount = 0
    override fun scopy(): MutableStruct = Version(this as MutableStruct)

    companion object {
    }
}

