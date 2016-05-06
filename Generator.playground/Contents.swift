import Swift
import Darwin

struct MyEmptyGenerator<Element> : GeneratorType {
    mutating func next() -> Element? {
        return nil
    }
}

var e = MyEmptyGenerator<Int>()
e.next()
e.next()

struct MyGeneratorOfOne<Element> : GeneratorType {
    var element: Element?
    init(_ element: Element?) { self.element = element }

    mutating func next() -> Element? {
        defer { element = nil }
        return element
    }
}

var o = MyGeneratorOfOne(1)
o.next()
o.next()


var g = zip([0], [0]).generate()
g.next()
g.next()
g.next()

struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        n += 1
        return n
    }
}

var nats = NaturalGenerator()
nats.next()


struct RandomGenerator : GeneratorType {
    var n: Int
    let limit: UInt32

    mutating func next() -> UInt32? {
        if n > 0 {
            n -= 1
            return arc4random_uniform(limit)
        }
        return nil
    }
}

var r = RandomGenerator(n: 1, limit: UInt32(100))
r.next()
r.next()

func makeNaturalGenerator() -> AnyGenerator<Int> {
    var n = 0
    return AnyGenerator{
        n += 1
        return n
    }
}

func makeNaturalGenerator2() -> AnyGenerator<Int> {
    return AnyGenerator(NaturalGenerator())
}
