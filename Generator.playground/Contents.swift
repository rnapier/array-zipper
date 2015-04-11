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

struct MyGeneratorOfOne<T> : GeneratorType {
    var element: T?
    init(_ element: T?) { self.element = element }

    mutating func next() -> T? {
        let result = self.element
        self.element = nil
        return result
    }
}

struct MyGeneratorOfOne2<T> : GeneratorType {
    var element: T?
    var done = false
    init(_ element: T?) { self.element = element }

    mutating func next() -> T? {
        precondition(!done, "Generator exhausted")
        let result = self.element
        self.element = nil
        self.done = (result == nil)
        return result
    }
}


var o:MyGeneratorOfOne2<Int> = MyGeneratorOfOne2(1)
o.next()
o.next()


var g = zip([0], [0]).generate()
g.next()
g.next()
g.next()

struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        return n++
    }
}

var nats = NaturalGenerator()
nats.next()


func withoutOutliers<S: SequenceType where S.Generator.Element : Comparable>(xs: S) -> [S.Generator.Element]{
    let mn = minElement(xs)
    let mx = maxElement(xs)

    return filter(xs) { $0 != mn && $0 != mx }
}

withoutOutliers([1,2,3,2,1])

struct RandomGenerator : GeneratorType {
    let limit: UInt32
    var n: Int

    mutating func next() -> UInt32? {
        if n > 0 {
            --n
            return arc4random_uniform(limit)
        }
        return nil
    }
    init(n: Int, limit: UInt32) {
        self.limit = limit
        self.n = n
    }
}

var r = RandomGenerator(n: 1, limit: UInt32(100))
r.next()
r.next()

func makeNaturalGenerator() -> GeneratorOf<Int> {
    var n = 0
    return GeneratorOf{ return n++ }
}

func makeNaturalGenerator2() -> GeneratorOf<Int> {
    return GeneratorOf(NaturalGenerator())
}
