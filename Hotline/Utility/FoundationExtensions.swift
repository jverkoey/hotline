import Foundation

enum Endianness {
  case big
  case little
}

extension String {
  func convertToAttributedStringWithLinks(relaxed: Bool = false) -> AttributedString {
    let attributedString: NSMutableAttributedString = NSMutableAttributedString(string: self)
    let urlPattern = relaxed ?
      #"(hotline|http|https)?(://)?[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?"# :
      #"(hotline|http|https)://[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?"#
    
    guard let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) else {
      return AttributedString(attributedString)
    }

    regex.enumerateMatches(in: self, range: NSMakeRange(0, self.count)) { (result: NSTextCheckingResult!, _, _) in
      if let newRange = Range(result.range, in: self) {
        let str = String(self[newRange])
        attributedString.addAttribute(.link, value: str, range: result.range)
      }
    }
    
    return AttributedString(attributedString)
  }
  
  func isWebURL() -> Bool {
    guard let url = URL(string: self) else {
      return false
    }
    switch url.scheme?.lowercased() {
    case "http", "https":
      return true
    default:
      return false
    }
  }
  
  func isImageURL() -> Bool {
    guard let url = URL(string: self) else {
      return false
    }
    
    switch url.pathExtension.lowercased() {
    case "jpg", "jpeg", "png", "gif":
      return true
    default:
      return false
    }
  }
  
  func convertLinksToMarkdown() -> String {
    let urlPattern = #"(hotline|http|https)?(://)?[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?"#
    
    guard let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) else {
      return self
    }
    
    return regex.stringByReplacingMatches(in: self, range: NSRange(location: 0, length: self.count), withTemplate: "[$0]($0)")
  }
}

extension Array where Element == UInt8 {
  init(_ val: UInt8) {
    self.init()
    self.appendUInt8(val)
  }
  
  init(_ val: UInt16) {
    self.init()
    self.appendUInt16(val)
  }
  
  init(_ val: UInt32) {
    self.init()
    self.appendUInt32(val)
  }
  
  init(_ val: UInt64) {
    self.init()
    self.appendUInt64(val)
  }
  
  mutating func consumeUInt8() -> UInt8? {
    guard let val = self.readUInt8(at: 0) else {
      return nil
    }
    
    self.removeFirst(1)
    return val
  }
  
  mutating func consumeUInt16() -> UInt16? {
    guard let val = self.readUInt16(at: 0) else {
      return nil
    }
    
    self.removeFirst(2)
    return val
  }
  
  mutating func consumeUInt32() -> UInt32? {
    guard let val = self.readUInt32(at: 0) else {
      return nil
    }
    
    self.removeFirst(4)
    return val
  }
  
  mutating func consumeUInt64() -> UInt64? {
    guard let val = self.readUInt64(at: 0) else {
      return nil
    }
    
    self.removeFirst(8)
    return val
  }
  
  mutating func consume(_ length: Int) -> Bool {
    guard length <= self.count else {
      return false
    }
    
    self.removeFirst(length)
    return true
  }
  
  mutating func consumeBytes(_ length: Int) -> Data? {
    guard let val: Data = self.readData(at: 0, length: length) else {
      return nil
    }
    
    self.removeFirst(length)
    return val
  }
  
  mutating func consumeBytes(_ length: Int) -> [UInt8]? {
    guard let val: [UInt8] = self.readData(at: 0, length: length) else {
      return nil
    }
    
    self.removeFirst(length)
    return val
  }
  
  mutating func consumeDate() -> Date? {
    guard let date = self.readDate(at: 0) else {
      return nil
    }
    
    self.removeFirst(2 + 2 + 4)
    return date
  }
  
  mutating func consumePString() -> String? {
    let (str, len) = self.readPString(at: 0)
    guard let str = str else {
      return nil
    }
    if len == 0 {
      return ""
    }
    
    self.removeFirst(len)
    return str
  }
  
  mutating func consumeString(_ length: Int) -> String? {
    guard let val = self.readString(at: 0, length: length) else {
      return nil
    }
    
    self.removeFirst(length)
    return val
  }
  
  func readUInt8(at offset: Int) -> UInt8? {
    guard offset >= 0, offset + 1 <= self.count else {
      return nil
    }
    return self[offset]
  }
  
  func readUInt16(at offset: Int) -> UInt16? {
    guard offset >= 0, offset + 2 <= self.count else {
      return nil
    }
    
    return (UInt16(self[offset]) << 8) + UInt16(self[offset + 1])
  }
  
  func readUInt32(at offset: Int) -> UInt32? {
    guard offset >= 0, offset + 4 <= self.count else {
      return nil
    }
    
    return (UInt32(self[offset]) << 24) + (UInt32(self[offset + 1]) << 16) + (UInt32(self[offset + 2]) << 8) + UInt32(self[offset + 3])
  }
  
  func readUInt64(at offset: Int) -> UInt64? {
    guard offset >= 0, offset + 8 <= self.count else {
      return nil
    }
    
    let a: UInt64 = (UInt64(self[offset]) << 56) +
      (UInt64(self[offset + 1]) << 48) +
      (UInt64(self[offset + 2]) << 40) +
      (UInt64(self[offset + 3]) << 32)
    
    let b: UInt64 = (UInt64(self[offset + 4]) << 24) +
      (UInt64(self[offset + 5]) << 16) +
      (UInt64(self[offset + 6]) << 8) +
       UInt64(self[offset + 7])
    
    return a + b
  }
  
  func readDate(at offset: Int) -> Date? {
    guard offset >= 0, offset + 2 + 2 + 4 <= self.count else {
      return nil
    }
    
    if
      let year = self.readUInt16(at: offset),
      let ms = self.readUInt16(at: offset + 2),
      let secs = self.readUInt32(at: offset + 2 + 2) {
      return convertHotlineDate(year: year, seconds: secs, milliseconds: ms)
    }
    
    return nil
  }
  
  func readData(at offset: Int, length: Int) -> Data? {
    guard offset >= 0, offset + length <= self.count else {
      return nil
    }
    return Data(self[offset..<(offset + length)])
  }
  
  func readData(at offset: Int, length: Int) -> [UInt8]? {
    guard offset >= 0, offset + length <= self.count else {
      return nil
    }
    return Array(self[offset..<(offset + length)])
  }
  
  func readString(at offset: Int, length: Int) -> String? {
    guard let subdata: Data = self.readData(at: offset, length: length) else {
      return nil
    }
    
    if subdata.count == 0 {
      return ""
    }
    
    let allowedEncodings = [
      NSUTF8StringEncoding,
      NSShiftJISStringEncoding,
      NSUnicodeStringEncoding,
      NSWindowsCP1251StringEncoding
    ]

    var decodedNSString: NSString?
    let rawValue = NSString.stringEncoding(for: subdata, encodingOptions: [.allowLossyKey: false], convertedString: &decodedNSString, usedLossyConversion: nil)
    
    if allowedEncodings.contains(rawValue) {
      return decodedNSString as? String
    }
    
    else if rawValue > 1 {
      print("ENCODING FOUND \(rawValue)")
    }
    
    var macStr = String(data: subdata, encoding: .macOSRoman)
    if macStr == nil {
      macStr = String(data: subdata, encoding: .nonLossyASCII)
    }
    
    return macStr
  }
  
  func readPString(at offset: Int) -> (String?, Int) {
    guard offset >= 0, offset + 1 <= self.count else {
      return (nil, 0)
    }
    let len = Int(self.readUInt8(at: offset)!)
    guard offset + 1 + len <= self.count else {
      return (nil, 0)
    }
    return (self.readString(at: offset+1, length: len), 1 + len)
  }
  
  func readLongPString(at offset: Int) -> (String?, Int) {
    guard offset >= 0, offset + 2 <= self.count else {
      return (nil, 0)
    }
    let len = Int(self.readUInt16(at: offset)!)
    guard len > 0 else {
      return ("", 0)
    }
    guard offset + 2 + len <= self.count else {
      return (nil, 0)
    }
    return (self.readString(at: offset+2, length: len), len)
  }
  
  mutating func appendUInt8(_ value: UInt8, endianness: Endianness = .big) {
    let val = endianness == .big ? value.bigEndian : value.littleEndian
    self.append(val)
  }
  
  mutating func appendUInt16(_ value: UInt16, endianness: Endianness = .big) {
    let val = endianness == .big ? value.bigEndian : value.littleEndian
    let bytes: [UInt8] = [
      UInt8(val & 0x00FF),
      UInt8((val >> 8) & 0x00FF),
    ]
    self.append(contentsOf: bytes)
  }
  
  mutating func appendUInt32(_ value: UInt32, endianness: Endianness = .big) {
    let val = endianness == .big ? value.bigEndian : value.littleEndian
    let bytes: [UInt8] = [
      UInt8(val & 0x000000FF),
      UInt8((val >> 8) & 0x000000FF),
      UInt8((val >> 16) & 0x000000FF),
      UInt8((val >> 24) & 0x000000FF),
    ]
    self.append(contentsOf: bytes)
  }
  
  mutating func appendUInt64(_ value: UInt64, endianness: Endianness = .big) {
    let val: UInt64 = endianness == .big ? value.bigEndian : value.littleEndian
    let bytes: [UInt8] = [
      UInt8(val & 0x00000000000000FF),
      UInt8((val >> 8) & 0x00000000000000FF),
      UInt8((val >> 16) & 0x00000000000000FF),
      UInt8((val >> 24) & 0x00000000000000FF),
      UInt8((val >> 32) & 0x00000000000000FF),
      UInt8((val >> 40) & 0x00000000000000FF),
      UInt8((val >> 48) & 0x00000000000000FF),
      UInt8((val >> 56) & 0x00000000000000FF),
    ]
    self.append(contentsOf: bytes)
  }
  
  mutating func appendData(_ data: Data) {
    self.append(contentsOf: data)
  }
  
  mutating func appendData(_ data: [UInt8]) {
    self.append(contentsOf: data)
  }
}

extension Data {
  init(_ val: UInt8) {
    self.init()
    self.appendUInt8(val)
  }
  
  init(_ val: UInt16) {
    self.init()
    self.appendUInt16(val)
  }
  
  init(_ val: UInt32) {
    self.init()
    self.appendUInt32(val)
  }
  
  func readUInt8(at offset: Int) -> UInt8? {
    guard offset >= 0, offset + 1 <= self.count else {
      return nil
    }
    return self[offset]
  }
  
  func readUInt16(at offset: Int) -> UInt16? {
    guard offset >= 0, offset + 2 <= self.count else {
      return nil
    }
    
    return (UInt16(self[offset]) << 8) + UInt16(self[offset + 1])
  }
  
  func readUInt32(at offset: Int) -> UInt32? {
    guard offset >= 0, offset + 4 <= self.count else {
      return nil
    }
    
    return (UInt32(self[offset]) << 24) + (UInt32(self[offset + 1]) << 16) + (UInt32(self[offset + 2]) << 8) + UInt32(self[offset + 3])
  }
  
  func readUInt64(at offset: Int) -> UInt64? {
    guard offset >= 0, offset + 8 <= self.count else {
      return nil
    }
    
    return withUnsafeBytes { $0.load(as: UInt64.self ) }
  }
  
  func readDate(at offset: Int) -> Date? {
    guard offset >= 0, offset + 2 + 2 + 4 <= self.count else {
      return nil
    }
    
    if
      let year = self.readUInt16(at: offset),
      let ms = self.readUInt16(at: offset + 2),
      let secs = self.readUInt32(at: offset + 2 + 2) {
      return convertHotlineDate(year: year, seconds: secs, milliseconds: ms)
    }
    
    return nil
  }
    
  func readData(at offset: Int, length: Int) -> Data? {
    guard offset >= 0, offset + length <= self.count else {
      return nil
    }
    return self.subdata(in: offset..<(offset + length))
  }

  func readString(at offset: Int, length: Int) -> String? {
    let subdata = self[offset..<(offset + length)]
    if subdata.count == 0 {
      return ""
    }
    
    let allowedEncodings = [
      NSUTF8StringEncoding,
      NSShiftJISStringEncoding,
      NSUnicodeStringEncoding,
      NSWindowsCP1251StringEncoding
    ]

    var decodedNSString: NSString?
    let rawValue = NSString.stringEncoding(for: subdata, encodingOptions: [.allowLossyKey: false], convertedString: &decodedNSString, usedLossyConversion: nil)
    
    if allowedEncodings.contains(rawValue) {
      return decodedNSString as? String
    }
    
    else if rawValue > 1 {
      print("ENCODING FOUND \(rawValue)")
    }
    
    var macStr = String(data: subdata, encoding: .macOSRoman)
    if macStr == nil {
      macStr = String(data: subdata, encoding: .nonLossyASCII)
    }
    
    return macStr
  }
  
  func readPString(at offset: Int) -> (String?, Int) {
    guard offset >= 0, offset + 1 <= self.count else {
      return (nil, 0)
    }
    let len = Int(self.readUInt8(at: offset)!)
    guard offset + 1 + len <= self.count else {
      return (nil, 0)
    }
    return (self.readString(at: offset+1, length: len), 1 + len)
  }
  
  func readLongPString(at offset: Int) -> (String?, Int) {
    guard offset >= 0, offset + 2 <= self.count else {
      return (nil, 0)
    }
    let len = Int(self.readUInt16(at: offset)!)
    guard len > 0 else {
      return ("", 0)
    }
    guard offset + 2 + len <= self.count else {
      return (nil, 0)
    }
    return (self.readString(at: offset+2, length: len), len)
  }
  
  
  mutating func appendUInt8(_ value: UInt8, endianness: Endianness = .big) {
    var val = endianness == .big ? value.bigEndian : value.littleEndian
    append(&val, count: MemoryLayout<UInt8>.size)
  }
  
  mutating func appendUInt16(_ value: UInt16, endianness: Endianness = .big) {
    var val = endianness == .big ? value.bigEndian : value.littleEndian
    Swift.withUnsafeBytes(of: &val) { buffer in
      append(buffer.bindMemory(to: UInt8.self))
    }
//    append(&val, count: MemoryLayout<UInt16>.size)
  }
  
  mutating func appendUInt32(_ value: UInt32, endianness: Endianness = .big) {
    var val = endianness == .big ? value.bigEndian : value.littleEndian
    Swift.withUnsafeBytes(of: &val) { buffer in
      append(buffer.bindMemory(to: UInt8.self))
    }
//    append(&val, count: MemoryLayout<UInt32>.size)
  }
}

extension String {
  func fourCharCode() -> FourCharCode {
    guard self.count == 4 else {
      return 0
    }
    
    return self.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
  }
}

extension FourCharCode {
  func fourCharCode() -> String {
    let bytes = [
      UInt8((self >> 24) & 0xFF),
      UInt8((self >> 16) & 0xFF),
      UInt8((self >> 8) & 0xFF),
      UInt8(self & 0xFF)
    ]
    return String(bytes: bytes, encoding: .ascii) ?? ""
  }
}
