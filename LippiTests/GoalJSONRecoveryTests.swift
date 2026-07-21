import Foundation
import Testing
@testable import Lippi

struct GoalJSONRecoveryTests {
    @Test("Extracts a complete root object before trailing text")
    func extractsCompleteObject() throws {
        let response = "prefix {\"title\":\"Route\",\"items\":[\"one\"]} trailing"

        let recovered = try #require(GoalJSONRecovery.rootObject(in: response))
        let object = try #require(JSONSerialization.jsonObject(with: Data(recovered.utf8)) as? [String: Any])

        #expect(object["title"] as? String == "Route")
    }

    @Test("Closes a response truncated inside a string")
    func closesTruncatedString() throws {
        let response = """
        {"title":"Personal route","personalizedInsights":["Fits four hours weekly","Review scope before expanding"],"milestones":[{"title":"First","tasks":["Write a brief","Build a prototype"]}],"habits":[{"title":"Weekly review","detail":"Record one decision
        """

        let recovered = try #require(GoalJSONRecovery.rootObject(in: response))
        let object = try #require(JSONSerialization.jsonObject(with: Data(recovered.utf8)) as? [String: Any])

        #expect(object["title"] as? String == "Personal route")
        #expect((object["personalizedInsights"] as? [String])?.count == 2)
    }

    @Test("Falls back to the last valid structural comma")
    func trimsIncompleteProperty() throws {
        let response = "{\"title\":\"Route\",\"summary\":\"Useful\",\"milestones\":[{\"title\":\"Start\"}],\"unfinishedKey"

        let recovered = try #require(GoalJSONRecovery.rootObject(in: response))
        let object = try #require(JSONSerialization.jsonObject(with: Data(recovered.utf8)) as? [String: Any])

        #expect(object["title"] as? String == "Route")
        #expect((object["milestones"] as? [[String: Any]])?.count == 1)
    }
}
