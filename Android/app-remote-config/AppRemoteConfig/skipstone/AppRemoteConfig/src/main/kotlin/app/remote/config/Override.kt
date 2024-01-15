package app.remote.config

import skip.lib.*
import skip.lib.Array

import skip.foundation.*

class Override: MutableStruct {
    internal var conditions: Array<Condition>? = null
        get() = field.sref({ this.conditions = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }
    internal var schedule: Schedule? = null
        get() = field.sref({ this.schedule = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }
    internal var settings: Dictionary<String, Any>
        get() = field.sref({ this.settings = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }

    internal constructor(json: Dictionary<String, Any>) {
        val matching = (json["matching"] as? Array<Dictionary<String, Any>>)?.map(Condition)
        this.conditions = matching

        val matchtarget_0 = json["schedule"] as? Dictionary<String, Any>
        if (matchtarget_0 != null) {
            val schedule = matchtarget_0
            this.schedule = Schedule(json = schedule)
        } else {
            this.schedule = null
        }

        val matchtarget_1 = json["settings"] as? Dictionary<String, Any>
        if (matchtarget_1 != null) {
            val settings = matchtarget_1
            this.settings = settings
        } else {
            settings = dictionaryOf()
        }
    }

    private constructor(copy: MutableStruct) {
        @Suppress("NAME_SHADOWING", "UNCHECKED_CAST") val copy = copy as Override
        this.conditions = copy.conditions
        this.schedule = copy.schedule
        this.settings = copy.settings
    }

    override var supdate: ((Any) -> Unit)? = null
    override var smutatingcount = 0
    override fun scopy(): MutableStruct = Override(this as MutableStruct)

    companion object {
    }
}
