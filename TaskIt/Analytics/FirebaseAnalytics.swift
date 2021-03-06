import Firebase

/*
// To see analytics in debug console
// go to Product>Schemes>Edit
// check the -FIRAnalyticsDebugEnabled
// checkbox in the Run section
*/

class FirebaseAnalyticsTracker: AnalyticsTracker {
    private(set) var isActive = true

    func activate() {
        isActive = true
    }

    func deactivate() {
        isActive = false
    }

    func configure() {
        FirebaseApp.configure()
    }

    func logEvent(_ name: String, parameters: [String : Any]) {
        guard isActive else { return }
        Firebase.Analytics.logEvent(name, parameters: parameters)
    }
}
