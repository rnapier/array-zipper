//: Playground - noun: a place where people can play

import Swift
import UIKit
import CoreText

let e = "é"
e.utf8.count
e.utf16.count
e.unicodeScalars.count
e.characters.count

let face = "😠"
face.utf8.count
face.utf16.count
face.unicodeScalars.count
face.characters.count

let tone = "👱🏾"
tone.utf8.count
tone.utf16.count
tone.unicodeScalars.count
tone.characters.count

let family = "👨‍👨‍👦‍👦"
family.utf8.count
family.utf16.count
family.unicodeScalars.count
family.characters.count

let bismillah = "﷽"
bismillah.utf8.count
bismillah.utf16.count
bismillah.unicodeScalars.count
bismillah.characters.count


let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, bismillah, nil))
CTLineGetGlyphCount(line)
