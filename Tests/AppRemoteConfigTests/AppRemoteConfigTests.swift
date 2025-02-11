import XCTest
import Foundation
@testable import AppRemoteConfig

final class AppRemoteConfigTests: XCTestCase {
    
    func testParsing() async throws {
        let jsonString = """
         {
             "settings": {
                 "foo": true,
                 "bar": "hello world",
                 "baz": [
                     {
                         "abc": "def"
                     }
                 ],
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
                             "platform": "iOS",
                             "appVersionCode": 123,
                             "versionName": "String",
                             "appVersion": "2.0.0"
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
                             "platform": "iOS",
                             "appVersion": "<3.0.0"
                         },
                         {
                             "platform": "Android",
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
                 "author": "Johan",
                 "client": "Secret Agency"
             }
         }
         """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Bool
        XCTAssertEqual(foo, false)
        
        let bar = settings["bar"] as! String
        XCTAssertEqual(bar, "hello world")
    }
    
    func testOverridingWithAppVersion() async throws {
        let jsonString = """
        {
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
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Int
        XCTAssertEqual(foo, 2)
    }
    
    func testOverridingWithAppVersionRange() async throws {
        let jsonString = """
        {
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
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.6.9"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 1)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.7.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.8.123"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.1"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 1)
        }
    }
    
    func testOverridingWithMultipleOverrides() async throws {
        let jsonString = """
        {
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
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.6.9"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 1)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.7.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.8.123"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 3)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.1"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 1)
        }
    }
    
    func testVersionParsing() {
        do {
            let version = try! Version("1.0.0")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }
       
        do {
            let version = try! Version("1.0")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }
        
        do {
            let version = try! Version("1")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }
        
        do {
            let version = try! Version("1.0.0-test")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }
        
        do {
            let version = try! Version(" 1.0.0 ")
            XCTAssertEqual(version.rawValue, "1.0.0")
        }
    }
    
    func testVersionRangeParsing() {
        do {
            let versionRange = try! VersionRange("1.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0")
            XCTAssertFalse(versionRange.contains(try! Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("1.0.1")))
            XCTAssertFalse(versionRange.contains(try! Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.1")))
        }
       
        do {
            let versionRange = try! VersionRange("1.0-2.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0-2.0.0")
            XCTAssertFalse(versionRange.contains(try! Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(try! Version("1.9.0")))
            XCTAssertTrue(versionRange.contains(try! Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.1")))
        }
        
        do {
            let versionRange = try! VersionRange(">1")
            XCTAssertEqual(versionRange.rawValue, ">1.0.0")
            XCTAssertFalse(versionRange.contains(try! Version("0.9.9")))
            XCTAssertFalse(versionRange.contains(try! Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(try! Version("1.9.0")))
            XCTAssertTrue(versionRange.contains(try! Version("2.0.0")))
            XCTAssertTrue(versionRange.contains(try! Version("2.0.1")))
        }
        
        do {
            let versionRange = try! VersionRange("<=1.0.0")
            XCTAssertEqual(versionRange.rawValue, "<=1.0.0")
            XCTAssertTrue(versionRange.contains(try! Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("1.0.1")))
            XCTAssertFalse(versionRange.contains(try! Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.1")))
        }
        
        do {
            let versionRange = try! VersionRange("1.0.0>-<2.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0>-<2.0.0")
            XCTAssertFalse(versionRange.contains(try! Version("0.9.9")))
            XCTAssertFalse(versionRange.contains(try! Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(try! Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.1")))
        }
        
        do {
            let versionRange = try! VersionRange("1.0.0>-2.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0>-2.0.0")
            XCTAssertFalse(versionRange.contains(try! Version("0.9.9")))
            XCTAssertFalse(versionRange.contains(try! Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(try! Version("1.9.0")))
            XCTAssertTrue(versionRange.contains(try! Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.1")))
        }
        
        do {
            let versionRange = try! VersionRange("1.0.0-<2.0.0")
            XCTAssertEqual(versionRange.rawValue, "1.0.0-<2.0.0")
            XCTAssertFalse(versionRange.contains(try! Version("0.9.9")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.0")))
            XCTAssertTrue(versionRange.contains(try! Version("1.0.1")))
            XCTAssertTrue(versionRange.contains(try! Version("1.9.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.0")))
            XCTAssertFalse(versionRange.contains(try! Version("2.0.1")))
        }
    }
    
    func testNotMatchingWhenUnknownKeysArePresent() async throws {
        let jsonString = """
        {
            "settings": {
                "foo": 1
            },
            "overrides": [
                {
                    "matching": [
                        {
                            "appVersion": "1.0.0",
                            "unknownKey": "present"
                        }
                    ],
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Int
        XCTAssertEqual(foo, 1)
    }
    
    func testRelevantDates() async throws {
        let jsonString = """
        {
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
                    "schedule": {
                        "from": "2024-08-21T00:00:00Z",
                        "until": "2024-09-11T00:00:00Z"
                    },
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let config = try Config(json: json)
        let dates = try config.relevantResolutionDates(platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
       
        XCTAssertEqual(dates, [
            ISO8601DateFormatter().date(from: "2024-08-21T00:00:00Z")!,
            ISO8601DateFormatter().date(from: "2024-09-11T00:00:00Z")!
        ])
    }

    func testRelevantDatesWithOtherZones() async throws {
        let jsonString = """
        {
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
                    "schedule": {
                        "from": "2024-08-21T00:00:00+0100",
                        "until": "2024-09-11T00:00:00-09:00"
                    },
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let config = try Config(json: json)
        let dates = try config.relevantResolutionDates(platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
       
        XCTAssertEqual(dates, [
            ISO8601DateFormatter().date(from: "2024-08-20T23:00:00Z")!,
            ISO8601DateFormatter().date(from: "2024-09-11T09:00:00Z")!
        ])
    }
    
    func testOverridingWithABuildVariant() async throws {
        let jsonString = """
        {
            "settings": {
                "foo": 1
            },
            "overrides": [
                {
                    "matching": [
                        {
                            "buildVariant": "debug"
                        }
                    ],
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .debug)
            
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 2)
        }
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
            
            let foo = settings["foo"] as! Int
            XCTAssertEqual(foo, 1)
        }
    }
    
    func testOverridingWithAnUnsupportedBuildVariant() async throws {
        let jsonString = """
        {
            "settings": {
                "foo": 1
            },
            "overrides": [
                {
                    "matching": [
                        {
                            "buildVariant": "unsupported variant"
                        }
                    ],
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Int
        XCTAssertEqual(foo, 1)
    }

    func testOverridingWithInvalidKeys() async throws {
        let jsonString = """
        {
            "settings": {
                "foo": 1
            },
            "overrides": [
                {
                    "matching": [
                        {
                            "buildVariant": "unsupported variant",
                            "platform": true
                        }
                    ],
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Int
        XCTAssertEqual(foo, 1)
    }

    func testOverridingWithUnknownPlatform() async throws {
        let jsonString = """
        {
            "settings": {
                "foo": 1
            },
            "overrides": [
                {
                    "matching": [
                        {
                            "platform": "unsupported platform"
                        }
                    ],
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Int
        XCTAssertEqual(foo, 1)
    }

    func testOverridingWithUnsupportedKey() async throws {
        let jsonString = """
        {
            "settings": {
                "foo": 1
            },
            "overrides": [
                {
                    "matching": [
                        {
                            "unsupported key": "unsupported value"
                        }
                    ],
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Int
        XCTAssertEqual(foo, 1)
    }


    func testOverridingWithUnsupportedAppVersion() async throws {
        let jsonString = """
        {
            "settings": {
                "foo": 1
            },
            "overrides": [
                {
                    "matching": [
                        {
                            "appVersion": "unsupported value"
                        }
                    ],
                    "settings": {
                        "foo": 2
                    }
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Sendable]
        
        let date = Date(timeIntervalSince1970: 0)
        let config = try Config(json: json)
        let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
        
        let foo = settings["foo"] as! Int
        XCTAssertEqual(foo, 1)
    }
}
