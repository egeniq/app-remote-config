package app.remote.config

import skip.lib.*
import skip.lib.Array

import skip.foundation.*

enum class BuildVariant(override val rawValue: String, @Suppress("UNUSED_PARAMETER") unusedp: Nothing? = null): CaseIterable, RawRepresentable<String> {
    release("release"),
    debug("debug"),
    unknown("unknown");

    companion object {
        val allCases: Array<BuildVariant>
            get() = arrayOf(release, debug, unknown)
    }
}

fun BuildVariant(rawValue: String): BuildVariant? {
    return when (rawValue) {
        "release" -> BuildVariant.release
        "debug" -> BuildVariant.debug
        "unknown" -> BuildVariant.unknown
        else -> null
    }
}

internal class Condition {
    internal val matchNever: Boolean
    internal val platform: Platform?
    internal val platformVersion: VersionRange?
    internal val appVersion: VersionRange?
    internal val variant: String?
    internal val buildVariant: BuildVariant?
    internal val language: String?

    internal constructor(json: Dictionary<String, Any>) {
        if (json.keys.contains(where = { it -> !arrayOf("platform", "platformVersion", "appVersion", "variant", "buildVariant", "language").contains(it) })) {
            matchNever = true
            platform = null
            platformVersion = null
            appVersion = null
            variant = null
            buildVariant = null
            language = null
            return
        }

        val matchtarget_0 = json["platform"]
        if (matchtarget_0 != null) {
            val jsonValue = matchtarget_0
            val matchtarget_1 = jsonValue as? String
            if (matchtarget_1 != null) {
                val string = matchtarget_1
                platform = Platform(rawValue = string) ?: Platform.unknown
            } else {
                matchNever = true
                platform = null
                platformVersion = null
                appVersion = null
                variant = null
                buildVariant = null
                language = null
                return
            }
        } else {
            platform = null
        }

        val matchtarget_2 = json["platformVersion"]
        if (matchtarget_2 != null) {
            val jsonValue = matchtarget_2
            val matchtarget_3 = jsonValue as? String
            if (matchtarget_3 != null) {
                val string = matchtarget_3
                val matchtarget_4 = try { VersionRange(string) } catch (_: Throwable) { null }
                if (matchtarget_4 != null) {
                    val platformVersion = matchtarget_4
                    this.platformVersion = platformVersion
                } else {
                    matchNever = true
                    platformVersion = null
                    appVersion = null
                    variant = null
                    buildVariant = null
                    language = null
                    return
                }
            } else {
                matchNever = true
                platformVersion = null
                appVersion = null
                variant = null
                buildVariant = null
                language = null
                return
            }
        } else {
            platformVersion = null
        }

        val matchtarget_5 = json["appVersion"]
        if (matchtarget_5 != null) {
            val jsonValue = matchtarget_5
            val matchtarget_6 = jsonValue as? String
            if (matchtarget_6 != null) {
                val string = matchtarget_6
                val matchtarget_7 = try { VersionRange(string) } catch (_: Throwable) { null }
                if (matchtarget_7 != null) {
                    val appVersion = matchtarget_7
                    this.appVersion = appVersion
                } else {
                    matchNever = true
                    appVersion = null
                    variant = null
                    buildVariant = null
                    language = null
                    return
                }
            } else {
                matchNever = true
                appVersion = null
                variant = null
                buildVariant = null
                language = null
                return
            }
        } else {
            appVersion = null
        }

        val matchtarget_8 = json["variant"]
        if (matchtarget_8 != null) {
            val jsonValue = matchtarget_8
            val matchtarget_9 = jsonValue as? String
            if (matchtarget_9 != null) {
                val string = matchtarget_9
                variant = string
            } else {
                matchNever = true
                variant = null
                buildVariant = null
                language = null
                return
            }
        } else {
            variant = null
        }

        val matchtarget_10 = json["buildVariant"]
        if (matchtarget_10 != null) {
            val jsonValue = matchtarget_10
            val matchtarget_11 = jsonValue as? String
            if (matchtarget_11 != null) {
                val string = matchtarget_11
                buildVariant = BuildVariant(rawValue = string) ?: BuildVariant.unknown
            } else {
                matchNever = true
                buildVariant = null
                language = null
                return
            }
        } else {
            buildVariant = null
        }

        val matchtarget_12 = json["language"]
        if (matchtarget_12 != null) {
            val jsonValue = matchtarget_12
            val matchtarget_13 = jsonValue as? String
            if (matchtarget_13 != null) {
                val string = matchtarget_13
                language = string
            } else {
                matchNever = true
                language = null
                return
            }
        } else {
            language = null
        }

        matchNever = false
    }

    internal fun matches(platform: Platform, platformVersion: Version, appVersion: Version, variant: String? = null, buildVariant: BuildVariant, language: String?): Boolean {
        if (matchNever) {
            return false
        }

        this.platform?.let { platformToMatch ->
            if (!platformToMatch.applies(to = platform)) {
                return false
            }
        }

        this.platformVersion?.let { platformVersionToMatch ->
            if (!platformVersionToMatch.contains(platformVersion)) {
                return false
            }
        }

        this.appVersion?.let { appVersionToMatch ->
            if (!appVersionToMatch.contains(appVersion)) {
                return false
            }
        }

        if (variant != null) {
            this.variant?.let { variantToMatch ->
                if (!variantToMatch.contains(variant)) {
                    return false
                }
            }
        }

        this.buildVariant?.let { buildVariantToMatch ->
            if (buildVariantToMatch != buildVariant) {
                return false
            }
        }

        if (language != null) {
            this.language?.let { languageToMatch ->
                if (!language.hasPrefix(languageToMatch)) {
                    return false
                }
            }
        }

        return true
    }
}
