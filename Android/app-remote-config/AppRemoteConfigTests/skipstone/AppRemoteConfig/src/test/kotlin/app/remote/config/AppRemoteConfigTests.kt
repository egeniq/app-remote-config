package app.remote.config

import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import skip.lib.*

import skip.unit.*
import skip.foundation.*
import app.remote.config.*

internal class AppRemoteConfigTests: XCTestCase {

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    internal fun runtestParsing() {
        val dispatcher = StandardTestDispatcher()
        Dispatchers.setMain(dispatcher)
        try {
            runTest { withContext(Dispatchers.Main) { testParsing() } }
        } finally {
            Dispatchers.resetMain()
        }
    }

    internal suspend fun testParsing(): Unit = Async.run {
        val jsonString = """{
    "settings": {
        // General
        "foo": true,
        "bar": "hello world",
        "baz": [
            {
                "abc": "def"
            }
        ],
        // Update
        "updateRequired": false,
        "updateRecommended": false,
        "appDisabled": false
    },
    "deprecatedKeys": [
        "old1",
        "old3"
    ],
    "overrides": [
        {
            "matching": [
                {
                    "variant": "AppStore"
                }
            ],
            "settings": {
                "foo": false
            }
        },
        {
            "matching": [
                {
                    "platform": "ios",
                    // "othe": [2, 0, 0],
                    "appVersionCode": 123,
                    "versionName": "String",
                    "appVersion": "2.0.0"  // 2 -> 2.0.0 2.0 -> 2.0.0  2.0.0-beta
                }
            ],
            "schedule": {
                
            },
            "settings": {
                "updateRecommended": true
            }
        },
        {
            "matching": [
                {
                    "platform": "ios",
                    "appVersion": "<3.0.0"
                },
                {
                    "platform": "android",
                    "appVersionCode": "<123"
                }
            ],
            "settings": {
                "updateRequired": true
            }
        }
    ],
    "meta": {
        "updated": "2024-01-08T12:00:00Z",
        // "sequence"
        "author": "Johan",
        "client": "Secret Agency"
    }
}"""
        val data = jsonString.data(using = StringEncoding.utf8)!!
        val json = (JSONSerialization.jsonObject(with = data, options = JSONSerialization.ReadingOptions.json5Allowed) as Dictionary<String, Any>).sref()

        val date = Date(timeIntervalSince1970 = 0)
        val config = Config(json = json)
        val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("1.0.0"), buildVariant = BuildVariant.release)

        val foo = settings["foo"] as Boolean
        XCTAssertEqual(foo, false)

        val bar = settings["bar"] as String
        XCTAssertEqual(bar, "hello world")
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    internal fun runtestOverridingWithAppVersion() {
        val dispatcher = StandardTestDispatcher()
        Dispatchers.setMain(dispatcher)
        try {
            runTest { withContext(Dispatchers.Main) { testOverridingWithAppVersion() } }
        } finally {
            Dispatchers.resetMain()
        }
    }

    internal suspend fun testOverridingWithAppVersion(): Unit = Async.run {
        val jsonString = """{
    "settings": {
        "foo": 1
    },
    "overrides": [
        {
            "matching": [
                {
                    "appVersion": "1.0.0"
                }
            ],
            "settings": {
                "foo": 2
            }
        }
    ]
}"""
        val data = jsonString.data(using = StringEncoding.utf8)!!
        val json = (JSONSerialization.jsonObject(with = data, options = JSONSerialization.ReadingOptions.json5Allowed) as Dictionary<String, Any>).sref()

        val date = Date(timeIntervalSince1970 = 0)
        val config = Config(json = json)
        val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("1.0.0"), buildVariant = BuildVariant.release)

        val foo = settings["foo"] as Int
        XCTAssertEqual(foo, 2)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    internal fun runtestOverridingWithAppVersionRange() {
        val dispatcher = StandardTestDispatcher()
        Dispatchers.setMain(dispatcher)
        try {
            runTest { withContext(Dispatchers.Main) { testOverridingWithAppVersionRange() } }
        } finally {
            Dispatchers.resetMain()
        }
    }

    internal suspend fun testOverridingWithAppVersionRange(): Unit = Async.run {
        val jsonString = """{
    "settings": {
        "foo": 1
    },
    "overrides": [
        {
            "matching": [
                {
                    "appVersion": "0.7.0-1.0.0"
                }
            ],
            "settings": {
                "foo": 2
            }
        }
    ]
}"""
        val data = jsonString.data(using = StringEncoding.utf8)!!
        val json = (JSONSerialization.jsonObject(with = data, options = JSONSerialization.ReadingOptions.json5Allowed) as Dictionary<String, Any>).sref()

        val date = Date(timeIntervalSince1970 = 0)
        val config = Config(json = json)

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("0.6.9"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 1)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("0.7.0"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 2)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("0.8.123"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 2)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("1.0.0"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 2)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("1.0.1"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 1)
        }
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    internal fun runtestOverridingWithMultipleOverrides() {
        val dispatcher = StandardTestDispatcher()
        Dispatchers.setMain(dispatcher)
        try {
            runTest { withContext(Dispatchers.Main) { testOverridingWithMultipleOverrides() } }
        } finally {
            Dispatchers.resetMain()
        }
    }

    internal suspend fun testOverridingWithMultipleOverrides(): Unit = Async.run {
        val jsonString = """{
    "settings": {
        "foo": 1
    },
    "overrides": [
        {
            "matching": [
                {
                    "appVersion": "0.7.0-1.0.0"
                }
            ],
            "settings": {
                "foo": 2
            }
        },
        {
            "matching": [
                {
                    "appVersion": "1.0.0"
                }
            ],
            "settings": {
                "foo": 3
            }
        }
    ]
}"""
        val data = jsonString.data(using = StringEncoding.utf8)!!
        val json = (JSONSerialization.jsonObject(with = data, options = JSONSerialization.ReadingOptions.json5Allowed) as Dictionary<String, Any>).sref()

        val date = Date(timeIntervalSince1970 = 0)
        val config = Config(json = json)

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("0.6.9"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 1)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("0.7.0"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 2)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("0.8.123"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 2)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("1.0.0"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 3)
        }

        run {
            val settings = config.resolve(date = date, platform = Platform.iOS_iPhone, platformVersion = Version("16.0.1"), appVersion = Version("1.0.1"), buildVariant = BuildVariant.release)
            val foo = settings["foo"] as Int
            XCTAssertEqual(foo, 1)
        }
    }

    @Test
    internal fun testVersionParsing() {
        run {
            val version = Version("1.0.0")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }

        run {
            val version = Version("1.0")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }

        run {
            val version = Version("1")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }

        run {
            val version = Version("1.0.0-test")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }

        run {
            val version = Version(" 1.0.0 ")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }
    }

    @Test
    internal fun testVersionRangeParsing() {
        run {
            val versionRange = VersionRange("1.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0")
            XCTAssertFalse(versionRange.contains(Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(Version("1.0.0")))
            XCTAssertFalse(versionRange.contains(Version("1.0.1")))
            XCTAssertFalse(versionRange.contains(Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.1")))
        }

        run {
            val versionRange = VersionRange("1.0-2.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0-2.0.0")
            XCTAssertFalse(versionRange.contains(Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(Version("1.9.0")))
            XCTAssertTrue(versionRange.contains(Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.1")))
        }

        run {
            val versionRange = VersionRange(">1")
            XCTAssertEqual(versionRange.rawValue, ">1.0.0")
            XCTAssertFalse(versionRange.contains(Version("0.9.9")))
            XCTAssertFalse(versionRange.contains(Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(Version("1.9.0")))
            XCTAssertTrue(versionRange.contains(Version("2.0.0")))
            XCTAssertTrue(versionRange.contains(Version("2.0.1")))
        }

        run {
            val versionRange = VersionRange("<=1.0.0")
            XCTAssertEqual(versionRange.rawValue, "<=1.0.0")
            XCTAssertTrue(versionRange.contains(Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(Version("1.0.0")))
            XCTAssertFalse(versionRange.contains(Version("1.0.1")))
            XCTAssertFalse(versionRange.contains(Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.1")))
        }

        run {
            val versionRange = VersionRange("1.0.0>-<2.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0>-<2.0.0")
            XCTAssertFalse(versionRange.contains(Version("0.9.9")))
            XCTAssertFalse(versionRange.contains(Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.1")))
        }

        run {
            val versionRange = VersionRange("1.0.0>-2.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0>-2.0.0")
            XCTAssertFalse(versionRange.contains(Version("0.9.9")))
            XCTAssertFalse(versionRange.contains(Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(Version("1.9.0")))
            XCTAssertTrue(versionRange.contains(Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.1")))
        }

        run {
            val versionRange = VersionRange("1.0.0-<2.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0-<2.0.0")
            XCTAssertFalse(versionRange.contains(Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(Version("2.0.1")))
        }
    }
}
