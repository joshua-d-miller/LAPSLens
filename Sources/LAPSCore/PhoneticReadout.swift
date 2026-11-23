import Foundation

/// Spells a password for reading aloud over the phone to a user at the Mac,
/// e.g. "aB3!" → ["alfa", "BRAVO", "three", "exclamation mark"].
/// Uppercase letters are written in capitals so the UI can mark them.
public enum PhoneticReadout {
    static let letters: [Character: String] = [
        "a": "alfa", "b": "bravo", "c": "charlie", "d": "delta", "e": "echo",
        "f": "foxtrot", "g": "golf", "h": "hotel", "i": "india", "j": "juliett",
        "k": "kilo", "l": "lima", "m": "mike", "n": "november", "o": "oscar",
        "p": "papa", "q": "quebec", "r": "romeo", "s": "sierra", "t": "tango",
        "u": "uniform", "v": "victor", "w": "whiskey", "x": "x-ray", "y": "yankee",
        "z": "zulu"
    ]
    static let digits: [Character: String] = [
        "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
        "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine"
    ]
    static let symbols: [Character: String] = [
        "!": "exclamation mark", "@": "at sign", "#": "hash", "$": "dollar sign",
        "%": "percent", "^": "caret", "&": "ampersand", "*": "asterisk",
        "(": "open parenthesis", ")": "close parenthesis", "-": "hyphen",
        "_": "underscore", "=": "equals", "+": "plus", "[": "open bracket",
        "]": "close bracket", "{": "open brace", "}": "close brace",
        "\\": "backslash", "|": "vertical bar", ";": "semicolon", ":": "colon",
        "'": "apostrophe", "\"": "quotation mark", ",": "comma", ".": "period",
        "<": "less than", ">": "greater than", "/": "slash", "?": "question mark",
        "`": "backtick", "~": "tilde", " ": "space"
    ]

    public static func words(for password: String) -> [String] {
        password.map { character in
            if character.isASCII, character.isLetter, let word = letters[Character(character.lowercased())] {
                return character.isUppercase ? word.uppercased() : word
            }
            if let word = digits[character] ?? symbols[character] {
                return word
            }
            return String(character)
        }
    }
}
