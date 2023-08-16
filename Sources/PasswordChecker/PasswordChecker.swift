import JavaScriptCore

public enum PasswordCheckerError: Error {
    case unableToCreateJSContext
    case unableToGetScript
    case unableToParseResult
}

// For more, available properties - https://github.com/dropbox/zxcvbn#usage

public struct PasswordInfo {
    public let guesses: Int32
    public let guessesLog10: Double
    public let crackTimesSeconds: [String: Double]
    public let crackTimesDisplay: [String: String]
    public let score: Int32
    public let calcTime: Int32
    public let warning: String
    public let suggestions: [String]

    public init(guesses: Int32 = 0,
                guessesLog10: Double = 0.0,
                crackTimesSeconds: [String: Double] = [:],
                crackTimesDisplay: [String: String] = [:],
                score: Int32 = 0,
                calcTime: Int32 = 0,
                warning: String = "",
                suggestions: [String] = []) {
        self.guesses = guesses
        self.guessesLog10 = guessesLog10
        self.crackTimesSeconds = crackTimesSeconds
        self.crackTimesDisplay = crackTimesDisplay
        self.score = score
        self.calcTime = calcTime
        self.warning = warning
        self.suggestions = suggestions
    }

    public static let empty = PasswordInfo()
}

public class PasswordChecker {

    private let jsContext: JSContext

    public init() throws {
        guard let jsContext = JSContext() else {
            throw PasswordCheckerError.unableToCreateJSContext
        }

        guard let passwordCheckerPath = Bundle.resources?.path(forResource: JSScript.scriptName, ofType: JSScript.scriptType),
              let passwordCheckerJS = try? String(contentsOfFile: passwordCheckerPath, encoding: String.Encoding.utf8) else {

            throw PasswordCheckerError.unableToGetScript
        }

        jsContext.exceptionHandler = { _, exception in
            assertionFailure(exception?.toString() ?? JSScript.unknownError)
        }

        jsContext.evaluateScript(passwordCheckerJS)

        self.jsContext = jsContext
    }

    public func getPasswordScore(_ password: String, userInputs: [String] = []) -> Result<PasswordInfo, PasswordCheckerError> {

        let result = jsContext.objectForKeyedSubscript(JSScript.scriptName)?
            .call(withArguments: [password, userInputs])

        guard let guesses = result?.objectForKeyedSubscript(JSKey.guesses.rawValue)?.toInt32() else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }

        guard let guessesLog10 = result?.objectForKeyedSubscript(JSKey.guessesLog10.rawValue)?.toDouble() else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }

        guard let secondsDictionary = result?.objectForKeyedSubscript(JSKey.crackTimesSeconds.rawValue)?.toDictionary(),
              let crackTimesSeconds = secondsDictionary as? [String: Double] else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }

        guard let displayDictionary = result?.objectForKeyedSubscript(JSKey.crackTimesDisplay.rawValue)?.toDictionary(),
              let crackTimesDisplay = displayDictionary as? [String: String] else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }

        guard let score = result?.objectForKeyedSubscript(JSKey.score.rawValue)?.toInt32() else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }

        guard let calcTime = result?.objectForKeyedSubscript(JSKey.calcTime.rawValue)?.toInt32() else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }
        
        guard let warning = result?.objectForKeyedSubscript(JSKey.feedback.rawValue).objectForKeyedSubscript(JSKey.warning.rawValue).toString() else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }
        
        guard let suggestions = result?.objectForKeyedSubscript(JSKey.feedback.rawValue).objectForKeyedSubscript(JSKey.suggestions.rawValue).toArray() as? [String] else {
            return .failure(PasswordCheckerError.unableToParseResult)
        }

        let passwordInfo = PasswordInfo(guesses: guesses,
                                        guessesLog10: guessesLog10,
                                        crackTimesSeconds: crackTimesSeconds,
                                        crackTimesDisplay: crackTimesDisplay,
                                        score: score,
                                        calcTime: calcTime,
                                        warning: warning,
                                        suggestions: suggestions)

        return .success(passwordInfo)
    }
}

private extension PasswordChecker {

    enum JSKey: String, RawRepresentable {
        case guesses = "guesses"
        case guessesLog10 = "guesses_log10"
        case crackTimesSeconds = "crack_times_seconds"
        case crackTimesDisplay = "crack_times_display"
        case score
        case calcTime = "calc_time"
        case feedback
        case warning
        case suggestions
    }

    enum JSScript {
        static let scriptName = "zxcvbn"
        static let scriptType = "js"
        static let unknownError = "Unknown JSError"
    }
}
