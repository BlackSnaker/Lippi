import Testing
@testable import Lippi

struct AppleWatchSyncOfferPolicyTests {
    @Test("Offers sync after onboarding when a paired Watch is detected")
    func offersForPairedWatch() {
        #expect(AppleWatchSyncOfferPolicy.shouldOffer(
            availability: .paired,
            hasCompletedOnboarding: true,
            isAuthenticated: true,
            healthInsightsEnabled: false,
            hasResponded: false
        ))
        #expect(AppleWatchSyncOfferPolicy.shouldOffer(
            availability: .reachable,
            hasCompletedOnboarding: true,
            isAuthenticated: true,
            healthInsightsEnabled: false,
            hasResponded: false
        ))
    }

    @Test("Does not interrupt onboarding or repeat a handled offer")
    func suppressesPrematureAndRepeatedOffers() {
        #expect(!AppleWatchSyncOfferPolicy.shouldOffer(
            availability: .paired,
            hasCompletedOnboarding: false,
            isAuthenticated: true,
            healthInsightsEnabled: false,
            hasResponded: false
        ))
        #expect(!AppleWatchSyncOfferPolicy.shouldOffer(
            availability: .paired,
            hasCompletedOnboarding: true,
            isAuthenticated: true,
            healthInsightsEnabled: false,
            hasResponded: true
        ))
    }

    @Test("Does not offer when sync is already active or no Watch is paired")
    func suppressesIrrelevantOffers() {
        #expect(!AppleWatchSyncOfferPolicy.shouldOffer(
            availability: .notPaired,
            hasCompletedOnboarding: true,
            isAuthenticated: true,
            healthInsightsEnabled: false,
            hasResponded: false
        ))
        #expect(!AppleWatchSyncOfferPolicy.shouldOffer(
            availability: .paired,
            hasCompletedOnboarding: true,
            isAuthenticated: true,
            healthInsightsEnabled: true,
            hasResponded: false
        ))
    }
}
