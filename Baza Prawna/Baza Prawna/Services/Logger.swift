import Foundation

#if DEBUG
func secureLog(_ message: @autoclosure () -> String) {
    print(message())
}
#else
func secureLog(_ message: @autoclosure () -> String) {
    // Logging disabled for release builds to avoid leaking sensitive data.
}
#endif

