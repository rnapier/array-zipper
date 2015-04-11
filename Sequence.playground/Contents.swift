// Playground - noun: a place where people can play

import Swift

struct MyEmptySequence<T> : SequenceType {
    func generate() -> EmptyGenerator<T> {
        return EmptyGenerator()
    }
}

let es = MyEmptySequence<Int>()
for x in es {
    fatalError("This should never run")
}

struct NaturalSequence : SequenceType {
    func generate() -> GeneratorOf<Int> {
        var n = 0
        return GeneratorOf{ n++ }
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

take(10, NaturalSequence())

let nats = SequenceOf { () -> GeneratorOf<Int> in
    var n = 0
    return GeneratorOf { n++ }
}
take(10, nats)


func drop<Seq: SequenceType>(n: Int, xs: Seq) -> SequenceOf<Seq.Generator.Element> {
    var g = xs.generate()
    for _ in 1...n { g.next() }
    return SequenceOf{g}
}

Array(drop(2, [1,2,3]))

underestimateCount(nats)

func myCount<Seq: SequenceType>(xs: Seq) -> Int {
    return reduce(xs, 0) { (n, _) in n + 1 }
}

func myCount2<Seq: SequenceType>(xs: Seq) -> Int {
    var n = 0
    for _ in xs { ++n }
    return n
}

underestimateCount(NaturalSequence())


