import AppRemoteConfigMacrosPlugin
// Select "My Mac" as destination if the plugin cannot be found!
import MacroTesting
import XCTest

final class AppRemoteConfigValuesMacroTests: BaseTestCase {
    override func invokeTest() {
        withMacroTesting(
            // isRecording: true,
            macros: [AppRemoteConfigValuesMacro.self]
        ) {
            super.invokeTest()
        }
    }
    
    func testBasics() {
        assertMacro {
            """
            @AppRemoteConfigValues
            public class Values {
                public private(set) var newFeature: Bool = false
                public private(set) var otherFeature: Int = 42
                public private(set) var message: String = "Hello, world!"
                public private(set) var discount: Double = -7.25
                public private(set) var authors: [String] = ["Bob", "Jane", "Bob, Jr."]
                public private(set) var prices: [String: Double] = ["Book": 12.50, "Banana": 10, "Bread": 1.99]
            }
            """
        } expansion: {
            """
            public class Values {
                public private(set) var newFeature: Bool = false
                public private(set) var otherFeature: Int = 42
                public private(set) var message: String = "Hello, world!"
                public private(set) var discount: Double = -7.25
                public private(set) var authors: [String] = ["Bob", "Jane", "Bob, Jr."]
                public private(set) var prices: [String: Double] = ["Book": 12.50, "Banana": 10, "Bread": 1.99]

                public init(
                    newFeature: Bool = false,
                    otherFeature: Int = 42,
                    message: String = "Hello, world!",
                    discount: Double = -7.25,
                    authors: [String] = ["Bob", "Jane", "Bob, Jr."],
                    prices: [String: Double] = ["Book": 12.50, "Banana": 10, "Bread": 1.99]
                ) {
                    self.newFeature = newFeature
                    self.otherFeature = otherFeature
                    self.message = message
                    self.discount = discount
                    self.authors = authors
                    self.prices = prices
                }

                func apply(settings: [String: Any]) throws {
                    var allKeys = Set(settings.keys)
                    var incorrectKeys = Set<String>()
                    var missingKeys = Set<String>()

                    if let newValue = settings["newFeature"] as? Bool  {
                        newFeature = newValue
                        allKeys.remove("newFeature")
                    } else {
                        newFeature = false
                        if allKeys.contains("newFeature") {
                            allKeys.remove("newFeature")
                            incorrectKeys.insert("newFeature")
                        } else {
                            missingKeys.insert("newFeature")
                        }
                    }

                    if let newValue = settings["otherFeature"] as? Int  {
                        otherFeature = newValue
                        allKeys.remove("otherFeature")
                    } else {
                        otherFeature = 42
                        if allKeys.contains("otherFeature") {
                            allKeys.remove("otherFeature")
                            incorrectKeys.insert("otherFeature")
                        } else {
                            missingKeys.insert("otherFeature")
                        }
                    }

                    if let newValue = settings["message"] as? String  {
                        message = newValue
                        allKeys.remove("message")
                    } else {
                        message = "Hello, world!"
                        if allKeys.contains("message") {
                            allKeys.remove("message")
                            incorrectKeys.insert("message")
                        } else {
                            missingKeys.insert("message")
                        }
                    }

                    if let newValue = settings["discount"] as? Double  {
                        discount = newValue
                        allKeys.remove("discount")
                    } else {
                        discount = -7.25
                        if allKeys.contains("discount") {
                            allKeys.remove("discount")
                            incorrectKeys.insert("discount")
                        } else {
                            missingKeys.insert("discount")
                        }
                    }

                    if let newValue = settings["authors"] as? [String]  {
                        authors = newValue
                        allKeys.remove("authors")
                    } else {
                        authors = ["Bob", "Jane", "Bob, Jr."]
                        if allKeys.contains("authors") {
                            allKeys.remove("authors")
                            incorrectKeys.insert("authors")
                        } else {
                            missingKeys.insert("authors")
                        }
                    }

                    if let newValue = settings["prices"] as? [String: Double]  {
                        prices = newValue
                        allKeys.remove("prices")
                    } else {
                        prices = ["Book": 12.50, "Banana": 10, "Bread": 1.99]
                        if allKeys.contains("prices") {
                            allKeys.remove("prices")
                            incorrectKeys.insert("prices")
                        } else {
                            missingKeys.insert("prices")
                        }
                    }

                    if !allKeys.isEmpty || !incorrectKeys.isEmpty || !missingKeys.isEmpty {
                        throw AppRemoteConfigServiceError.keysMismatch(unhandled: allKeys, incorrect: incorrectKeys, missing: missingKeys)
                    }
                }
            }
            """
        }
    }
    
    func testImmutableProperty() {
        assertMacro {
          """
          @AppRemoteConfigValues
          public class Values {
              public private(set) var newFeature: Bool = false
              public private(set) let otherFeature: Int
          }
          """
        } expansion: {
            """
            public class Values {
                public private(set) var newFeature: Bool = false
                public private(set) let otherFeature: Int

                public init(
                    newFeature: Bool = false,
                    otherFeature: Int
                ) {
                    self.newFeature = newFeature
                    self.otherFeature = otherFeature
                }

                func apply(settings: [String: Any]) throws {
                    var allKeys = Set(settings.keys)
                    var incorrectKeys = Set<String>()
                    var missingKeys = Set<String>()

                    if let newValue = settings["newFeature"] as? Bool  {
                        newFeature = newValue
                        allKeys.remove("newFeature")
                    } else {
                        newFeature = false
                        if allKeys.contains("newFeature") {
                            allKeys.remove("newFeature")
                            incorrectKeys.insert("newFeature")
                        } else {
                            missingKeys.insert("newFeature")
                        }
                    }

                    if !allKeys.isEmpty || !incorrectKeys.isEmpty || !missingKeys.isEmpty {
                        throw AppRemoteConfigServiceError.keysMismatch(unhandled: allKeys, incorrect: incorrectKeys, missing: missingKeys)
                    }
                }
            }
            """
        }
    }
    
    func testFunction() {
        assertMacro {
          """
          @AppRemoteConfigValues
          public class Values {
              public private(set) var newFeature: Bool = false
          
              public func doSomething() {
                  print("Hello, world!")
              }
          }
          """
        } expansion: {
            """
            public class Values {
                public private(set) var newFeature: Bool = false

                public func doSomething() {
                    print("Hello, world!")
                }

                public init(
                    newFeature: Bool = false
                ) {
                    self.newFeature = newFeature
                }

                func apply(settings: [String: Any]) throws {
                    var allKeys = Set(settings.keys)
                    var incorrectKeys = Set<String>()
                    var missingKeys = Set<String>()

                    if let newValue = settings["newFeature"] as? Bool  {
                        newFeature = newValue
                        allKeys.remove("newFeature")
                    } else {
                        newFeature = false
                        if allKeys.contains("newFeature") {
                            allKeys.remove("newFeature")
                            incorrectKeys.insert("newFeature")
                        } else {
                            missingKeys.insert("newFeature")
                        }
                    }

                    if !allKeys.isEmpty || !incorrectKeys.isEmpty || !missingKeys.isEmpty {
                        throw AppRemoteConfigServiceError.keysMismatch(unhandled: allKeys, incorrect: incorrectKeys, missing: missingKeys)
                    }
                }
            }
            """
        }
    }
    
    func testRawRepresentable() {
        assertMacro {
          """
          @AppRemoteConfigValues
          public class Values {
              var newFeature: String = NewFeature.veryCool.rawValue
              public var newFeatureEnum: NewFeature {
                  get {
                      NewFeature(rawValue: newFeature) ?? .veryCool
                  }
                  set {
                      newFeature = newValue.rawValue
                  }
              }
          }
          """
        } expansion: {
            """
            public class Values {
                var newFeature: String = NewFeature.veryCool.rawValue
                public var newFeatureEnum: NewFeature {
                    get {
                        NewFeature(rawValue: newFeature) ?? .veryCool
                    }
                    set {
                        newFeature = newValue.rawValue
                    }
                }

                init(
                    newFeature: String = NewFeature.veryCool.rawValue
                ) {
                    self.newFeature = newFeature
                }

                func apply(settings: [String: Any]) throws {
                    var allKeys = Set(settings.keys)
                    var incorrectKeys = Set<String>()
                    var missingKeys = Set<String>()

                    if let newValue = settings["newFeature"] as? String  {
                        newFeature = newValue
                        allKeys.remove("newFeature")
                    } else {
                        newFeature = NewFeature.veryCool.rawValue
                        if allKeys.contains("newFeature") {
                            allKeys.remove("newFeature")
                            incorrectKeys.insert("newFeature")
                        } else {
                            missingKeys.insert("newFeature")
                        }
                    }

                    if !allKeys.isEmpty || !incorrectKeys.isEmpty || !missingKeys.isEmpty {
                        throw AppRemoteConfigServiceError.keysMismatch(unhandled: allKeys, incorrect: incorrectKeys, missing: missingKeys)
                    }
                }
            }
            """
        }
    }
}
