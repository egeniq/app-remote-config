import AppRemoteConfigMacrosPlugin
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

                func apply(settings: [String: Any]) {
                    if let newValue = settings["newFeature"] as? Bool  {
                        newFeature = newValue
                    } else {
                        newFeature = false
                    }
                    if let newValue = settings["otherFeature"] as? Int  {
                        otherFeature = newValue
                    } else {
                        otherFeature = 42
                    }
                    if let newValue = settings["message"] as? String  {
                        message = newValue
                    } else {
                        message = "Hello, world!"
                    }
                    if let newValue = settings["discount"] as? Double  {
                        discount = newValue
                    } else {
                        discount = -7.25
                    }
                    if let newValue = settings["authors"] as? [String]  {
                        authors = newValue
                    } else {
                        authors = ["Bob", "Jane", "Bob, Jr."]
                    }
                    if let newValue = settings["prices"] as? [String: Double]  {
                        prices = newValue
                    } else {
                        prices = ["Book": 12.50, "Banana": 10, "Bread": 1.99]
                    }
                }
            }
            """
        }
    }
}
