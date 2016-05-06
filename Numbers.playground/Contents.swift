//: Playground - noun: a place where people can play

import UIKit
import Swift
0.1 * 9 * 10

10 * 9 * 0.01 == 0.01 * 9 * 10

let x = Float(100_000_000)
x == x + 1

let y = 0.0 / 0
1 <= y
1 >= y
y == y

Float.NaN.isSignaling

//Int32(1) == Int64(1)
//Float(0.1) == Double(0.1)

func something<F: FloatingPointType>(x: F) -> F {
    return F(0)
}

struct PackagingOptions : OptionSetType {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let Box = PackagingOptions(rawValue: 1)
    static let Carton = PackagingOptions(rawValue: 2)
    static let Bag = PackagingOptions(rawValue: 4)
    static let Satchel = PackagingOptions(rawValue: 8)
    static let BoxOrBag: PackagingOptions = [Box, Bag]
    static let BoxOrCartonOrBag: PackagingOptions = [Box, Carton, Bag]
}

func shipit(options: PackagingOptions) {
    if options.contains(.Carton) {
        print("We need a Carton")
    }
}

shipit(.Box)
shipit(.BoxOrCartonOrBag)
shipit([.Box, .Carton])