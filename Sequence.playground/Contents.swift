// Playground - noun: a place where people can play

import Swift

func withoutMinMax<Seq: SequenceType
    where Seq.Generator.Element : Comparable>
    (xs: Seq) -> [Seq.Generator.Element]{

    guard let
        mn = xs.minElement(),
        mx = xs.maxElement()
        else { return [] }

    return xs.filter { $0 != mn && $0 != mx }
}

struct MyEmptySequence<Element> : SequenceType {
    func generate() -> EmptyGenerator<Element> {
        return EmptyGenerator()
    }
}

for x in MyEmptySequence<Int>() {
    fatalError("This should never run")
}

struct NaturalSequence : SequenceType {
    func generate() -> AnyGenerator<Int> {
        var n = 0
        return AnyGenerator{
            n += 1
            return n
        }
    }
}

func take<Seq: SequenceType>(n: Int, xs: Seq) -> [Seq.Generator.Element] {
    var result: [Seq.Generator.Element] = []
    var g = xs.generate()
    for _ in 1...n {
        if let next = g.next() {
            result.append(next)
        } else {
            break
        }
    }
    return result
}

take(10, xs: NaturalSequence())

let nats = AnySequence { () -> AnyGenerator<Int> in
    var n = 0
    return AnyGenerator {
        n += 1
        return n
    }
}
take(10, xs: nats)

extension SequenceType {
    func drop(n: Int) -> AnySequence<Generator.Element> {
        var g = generate()
        for _ in 1...n { g.next() }
        return AnySequence{g}
    }
}

Array([1,2,3].drop(2))

nats.underestimateCount()

func myCount<Seq: SequenceType>(xs: Seq) -> Int {
    return xs.reduce(0) { (n, _) in n + 1 }
}

func myCount2<Seq: SequenceType>(xs: Seq) -> Int {
    var n = 0
    for _ in xs { n += 1 }
    return n
}

NaturalSequence().underestimateCount()


internal class _DropFirstSequence<Base : GeneratorType>
: SequenceType, GeneratorType {

    internal var generator: Base
    internal let limit: Int
    internal var dropped: Int

    internal init(_ generator: Base, limit: Int, dropped: Int = 0) {
        self.generator = generator
        self.limit = limit
        self.dropped = dropped
    }

    internal func generate() -> _DropFirstSequence<Base> {
        return self
    }

    internal func next() -> Base.Element? {
        while dropped < limit {
            if generator.next() == nil {
                dropped = limit
                return nil
            }
            dropped += 1
        }
        return generator.next()
    }

    internal func dropFirst(n: Int) -> AnySequence<Base.Element> {
        // If this is already a _DropFirstSequence, we need to fold in
        // the current drop count and drop limit so no data is lost.
        //
        // i.e. [1,2,3,4].dropFirst(1).dropFirst(1) should be equivalent to
        // [1,2,3,4].dropFirst(2).
        return AnySequence(
            _DropFirstSequence(generator, limit: limit + n, dropped: dropped))
    }
}


extension SequenceType where
    SubSequence : SequenceType,
    SubSequence.Generator.Element == Generator.Element
{

    /// Returns a subsequence containing all but the first `n` elements.
    ///
    /// - Requires: `n >= 0`
    /// - Complexity: O(`n`)
    @warn_unused_result
    public func mydropFirst(n: Int) -> AnySequence<Generator.Element> {
        _precondition(n >= 0, "Can't drop a negative number of elements from a sequence")
        if n == 0 { return AnySequence(self) }
        return AnySequence(_DropFirstSequence(generate(), limit: n))
    }
}