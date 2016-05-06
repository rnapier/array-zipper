import Swift
import Darwin

struct Random {
    subscript (n : UInt32) -> UInt32 {
        return arc4random_uniform(n)
    }
}

let r = Random()
r[100]
r[1000]
r[100]


struct MyEmptyCollection<T> : CollectionType {
    typealias Index = Int
    let startIndex = 0
    let endIndex = 0
    func generate() -> EmptyGenerator<T> {
        return EmptyGenerator()
    }

    subscript (position: Index) -> T {
        fatalError("Index out of range")
    }
}

let e = MyEmptyCollection<Int>()
for x in e {
    fatalError("This should never run")
}

func dropFirst<S: SequenceType>(seq: S) -> AnySequence<S.Generator.Element> {
    var g = seq.generate()
    let _ = g.next()
    return AnySequence{ g }
}

1 ... 6
