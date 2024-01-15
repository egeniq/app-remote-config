package app.remote.config

import skip.lib.*
import skip.lib.Array

import skip.foundation.*

class Config: MutableStruct {
    var settings: Dictionary<String, Any>
        get() = field.sref({ this.settings = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }
    var deprecatedKeys: Array<String>
        get() = field.sref({ this.deprecatedKeys = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }
    var overrides: Array<Override>
        get() = field.sref({ this.overrides = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }
    var meta: Dictionary<String, Any>
        get() = field.sref({ this.meta = it })
        set(newValue) {
            @Suppress("NAME_SHADOWING") val newValue = newValue.sref()
            willmutate()
            field = newValue
            didmutate()
        }

    constructor(json: Dictionary<String, Any>) {
        val matchtarget_0 = json["settings"]
        if (matchtarget_0 != null) {
            val jsonValue = matchtarget_0
            val dictionary_0 = (jsonValue as? Dictionary<String, Any>).sref()
            if (dictionary_0 == null) {
                throw ConfigError.unexpectedTypeForKey("settings")
            }
            settings = dictionary_0
        } else {
            settings = dictionaryOf()
        }
        deprecatedKeys = json["deprecatedKeys"] as? Array<String> ?: arrayOf()
        overrides = (json["overrides"] as? Array<Dictionary<String, Any>>)?.map(Override) ?: arrayOf()
        meta = json["meta"] as? Dictionary<String, Any> ?: dictionaryOf()
    }

    fun resolve(date: Date, platform: Platform, platformVersion: Version, appVersion: Version, variant: String? = null, buildVariant: BuildVariant, language: String? = null): Dictionary<String, Any> {
        return overrides.reduce(into = settings) { partialResult, override ->
            val isScheduled: Boolean
            val matchtarget_1 = override.schedule
            if (matchtarget_1 != null) {
                val schedule = matchtarget_1
                isScheduled = schedule.contains(date = date)
            } else {
                isScheduled = true
            }

            val matches: Boolean
            val matchtarget_2 = override.conditions
            if (matchtarget_2 != null) {
                val conditions = matchtarget_2
                matches = conditions.contains(where = { it -> it.matches(platform = platform, platformVersion = platformVersion, appVersion = appVersion, variant = variant, buildVariant = buildVariant, language = language) })
            } else {
                matches = true
            }

            if (isScheduled && matches) {
                for ((key, value) in override.settings.enumerated()) {
                    partialResult.value[key] = value.sref()
                }
            }
        }
    }

    fun relevantResolutionDates(platform: Platform, platformVersion: Version, appVersion: Version, variant: String? = null, buildVariant: BuildVariant, language: String? = null): Array<Date> {
        return overrides.reduce(into = Array<Date>(), l@{ partialResult, override ->
            val schedule_0 = override.schedule.sref()
            if (schedule_0 == null) {
                return@l
            }

            val matches: Boolean
            val matchtarget_3 = override.conditions
            if (matchtarget_3 != null) {
                val conditions = matchtarget_3
                matches = conditions.contains(where = { it -> it.matches(platform = platform, platformVersion = platformVersion, appVersion = appVersion, variant = variant, buildVariant = buildVariant, language = language) })
            } else {
                matches = true
            }

            if (matches) {
                schedule_0.from.sref()?.let { from ->
                    partialResult.value.append(from)
                }
                schedule_0.until.sref()?.let { until ->
                    partialResult.value.append(until)
                }
            }
        })
        .sorted()
    }


    private constructor(copy: MutableStruct) {
        @Suppress("NAME_SHADOWING", "UNCHECKED_CAST") val copy = copy as Config
        this.settings = copy.settings
        this.deprecatedKeys = copy.deprecatedKeys
        this.overrides = copy.overrides
        this.meta = copy.meta
    }

    override var supdate: ((Any) -> Unit)? = null
    override var smutatingcount = 0
    override fun scopy(): MutableStruct = Config(this as MutableStruct)

    companion object {
    }
}
