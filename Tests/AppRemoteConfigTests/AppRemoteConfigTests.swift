import Testing
import Foundation
@testable import AppRemoteConfig

struct AppRemoteConfigTests {
    
    @Test
    func parsing() async throws {
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
        #expect(foo == false)
        
        let bar = settings["bar"] as! String
        #expect(bar == "hello world")
    }
    
    @Test
    func overridingWithAppVersion() async throws {
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
        #expect(foo == 2)
    }
    
    @Test
    func overridingWithAppVersionRange() async throws {
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
            #expect(foo == 1)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.7.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.8.123"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.1"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 1)
        }
    }
    
    @Test
    func overridingWithMultipleOverrides() async throws {
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
            #expect(foo == 1)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.7.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("0.8.123"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 2)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 3)
        }
        
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.1"), buildVariant: .release)
            let foo = settings["foo"] as! Int
            #expect(foo == 1)
        }
    }
    
    @Test
    func versionParsing() {
        do {
            let version = try! Version("1.0.0")
            #expect(version.rawValue == "1.0.0")
        }
       
        do {
            let version = try! Version("1.0")
            #expect(version.rawValue == "1.0.0")
        }
        
        do {
            let version = try! Version("1")
            #expect(version.rawValue == "1.0.0")
        }
        
        do {
            let version = try! Version("1.0.0-test")
            #expect(version.rawValue == "1.0.0")
        }
        
        do {
            let version = try! Version(" 1.0.0 ")
            #expect(version.rawValue == "1.0.0")
        }
    }
    
    @Test
    func versionRangeParsing() {
        do {
            let versionRange = try! VersionRange("1.0.0")
            #expect(versionRange.rawValue == "1.0.0")
            #expect(!(versionRange.contains(try! Version("0.9.9"))))
            #expect(versionRange.contains(try! Version("1.0.0")))
            #expect(!(versionRange.contains(try! Version("1.0.1"))))
            #expect(!(versionRange.contains(try! Version("1.9.0"))))
            #expect(!(versionRange.contains(try! Version("2.0.0"))))
            #expect(!(versionRange.contains(try! Version("2.0.1"))))
        }
       
        do {
            let versionRange = try! VersionRange("1.0-2.0")
            #expect(versionRange.rawValue == "1.0.0-2.0.0")
            #expect(!(versionRange.contains(try! Version("0.9.9"))))
            #expect(versionRange.contains(try! Version("1.0.0")))
            #expect(versionRange.contains(try! Version("1.0.1")))
            #expect(versionRange.contains(try! Version("1.9.0")))
            #expect(versionRange.contains(try! Version("2.0.0")))
            #expect(!(versionRange.contains(try! Version("2.0.1"))))
        }
        
        do {
            let versionRange = try! VersionRange(">1")
            #expect(versionRange.rawValue == ">1.0.0")
            #expect(!(versionRange.contains(try! Version("0.9.9"))))
            #expect(!(versionRange.contains(try! Version("1.0.0"))))
            #expect(versionRange.contains(try! Version("1.0.1")))
            #expect(versionRange.contains(try! Version("1.9.0")))
            #expect(versionRange.contains(try! Version("2.0.0")))
            #expect(versionRange.contains(try! Version("2.0.1")))
        }
        
        do {
            let versionRange = try! VersionRange("<=1.0.0")
            #expect(versionRange.rawValue == "<=1.0.0")
            #expect(versionRange.contains(try! Version("0.9.9")))
            #expect(versionRange.contains(try! Version("1.0.0")))
            #expect(!(versionRange.contains(try! Version("1.0.1"))))
            #expect(!(versionRange.contains(try! Version("1.9.0"))))
            #expect(!(versionRange.contains(try! Version("2.0.0"))))
            #expect(!(versionRange.contains(try! Version("2.0.1"))))
        }
        
        do {
            let versionRange = try! VersionRange("1.0.0>-<2.0.0")
            #expect(versionRange.rawValue == "1.0.0>-<2.0.0")
            #expect(!(versionRange.contains(try! Version("0.9.9"))))
            #expect(!(versionRange.contains(try! Version("1.0.0"))))
            #expect(versionRange.contains(try! Version("1.0.1")))
            #expect(versionRange.contains(try! Version("1.9.0")))
            #expect(!(versionRange.contains(try! Version("2.0.0"))))
            #expect(!(versionRange.contains(try! Version("2.0.1"))))
        }
        
        do {
            let versionRange = try! VersionRange("1.0.0>-2.0.0")
            #expect(versionRange.rawValue == "1.0.0>-2.0.0")
            #expect(!(versionRange.contains(try! Version("0.9.9"))))
            #expect(!(versionRange.contains(try! Version("1.0.0"))))
            #expect(versionRange.contains(try! Version("1.0.1")))
            #expect(versionRange.contains(try! Version("1.9.0")))
            #expect(versionRange.contains(try! Version("2.0.0")))
            #expect(!(versionRange.contains(try! Version("2.0.1"))))
        }
        
        do {
            let versionRange = try! VersionRange("1.0.0-<2.0.0")
            #expect(versionRange.rawValue == "1.0.0-<2.0.0")
            #expect(!(versionRange.contains(try! Version("0.9.9"))))
            #expect(versionRange.contains(try! Version("1.0.0")))
            #expect(versionRange.contains(try! Version("1.0.1")))
            #expect(versionRange.contains(try! Version("1.9.0")))
            #expect(!(versionRange.contains(try! Version("2.0.0"))))
            #expect(!(versionRange.contains(try! Version("2.0.1"))))
        }
    }
    
    @Test
    func notMatchingWhenUnknownKeysArePresent() async throws {
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
        #expect(foo == 1)
    }
    
    @Test
    func relevantDates() async throws {
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
       
        #expect(dates == [
            ISO8601DateFormatter().date(from: "2024-08-21T00:00:00Z")!,
            ISO8601DateFormatter().date(from: "2024-09-11T00:00:00Z")!
        ])
    }

    @Test
    func relevantDatesWithOtherZones() async throws {
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
       
        #expect(dates == [
            ISO8601DateFormatter().date(from: "2024-08-20T23:00:00Z")!,
            ISO8601DateFormatter().date(from: "2024-09-11T09:00:00Z")!
        ])
    }
    
    @Test
    func overridingWithABuildVariant() async throws {
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
            #expect(foo == 2)
        }
        do {
            let settings = try config.resolve(date: date, platform: .iOS_iPhone, platformVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 1), appVersion: Version("1.0.0"), buildVariant: .release)
            
            let foo = settings["foo"] as! Int
            #expect(foo == 1)
        }
    }
    
    @Test
    func overridingWithAnUnsupportedBuildVariant() async throws {
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
        #expect(foo == 1)
    }

    @Test
    func overridingWithInvalidKeys() async throws {
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
        #expect(foo == 1)
    }

    @Test
    func overridingWithUnknownPlatform() async throws {
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
        #expect(foo == 1)
    }

    @Test
    func overridingWithUnsupportedKey() async throws {
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
        #expect(foo == 1)
    }


    @Test
    func overridingWithUnsupportedAppVersion() async throws {
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
        #expect(foo == 1)
    }
}
