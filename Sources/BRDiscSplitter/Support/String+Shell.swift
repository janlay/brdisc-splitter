import Foundation

extension String {
  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var shellQuoted: String {
    if isEmpty {
      return "''"
    }

    let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-./:=,@")
    if rangeOfCharacter(from: safeCharacters.inverted) == nil {
      return self
    }

    return "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}
