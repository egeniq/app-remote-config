package app.remote.config

import skip.lib.*

import skip.foundation.*

internal class Schedule: MutableStruct {
    internal val matchNever: Boolean
    internal var from: Date? = null
        get() = field.sref({ this.from = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }
    internal var until: Date? = null
        get() = field.sref({ this.until = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }

    internal constructor(json: Dictionary<String, Any>) {
        val matchtarget_0 = json["from"]
        if (matchtarget_0 != null) {
            val fromJSON = matchtarget_0
            val matchtarget_1 = fromJSON as? String
            if (matchtarget_1 != null) {
                val fromString = matchtarget_1
                val matchtarget_2 = Companion.dateFormatter.date(from = fromString)
                if (matchtarget_2 != null) {
                    val date = matchtarget_2
                    from = date
                } else {
                    matchNever = true
                    from = null
                    until = null
                    return
                }
            } else {
                matchNever = true
                from = null
                until = null
                return
            }
        } else {
            from = null
        }

        val matchtarget_3 = json["until"]
        if (matchtarget_3 != null) {
            val untilJSON = matchtarget_3
            val matchtarget_4 = untilJSON as? String
            if (matchtarget_4 != null) {
                val untilString = matchtarget_4
                val matchtarget_5 = Companion.dateFormatter.date(from = untilString)
                if (matchtarget_5 != null) {
                    val date = matchtarget_5
                    until = date
                } else {
                    matchNever = true
                    until = null
                    return
                }
            } else {
                matchNever = true
                until = null
                return
            }
        } else {
            until = null
        }

        matchNever = false
    }

    internal fun contains(date: Date): Boolean {
        if (matchNever) {
            return false
        }

        from.sref()?.let { from ->
            if (date.compare(from) == ComparisonResult.orderedAscending) {
                return false
            }
        }
        until.sref()?.let { until ->
            if (date.compare(until) != ComparisonResult.orderedAscending) {
                return false
            }
        }
        return true
    }

    private constructor(copy: MutableStruct) {
        @Suppress("NAME_SHADOWING", "UNCHECKED_CAST") val copy = copy as Schedule
        this.matchNever = copy.matchNever
        this.from = copy.from
        this.until = copy.until
    }

    override var supdate: ((Any) -> Unit)? = null
    override var smutatingcount = 0
    override fun scopy(): MutableStruct = Schedule(this as MutableStruct)

    companion object {

        internal var dateFormatter = ISO8601DateFormatter()
    }
}
