import Swift

let xs = [1,2,3,4,5]
let ys = ["one", "two", "three", "four", "five"]

for pair in zip(xs, ys) {
    println(pair)
}

let everyother = lazy(enumerate(xs))
    .filter { (i, v) in i % 2 == 0 }
    .map    { (_, v) in v }.array

func myEnumerate<Seq : SequenceType>(base: Seq)
    -> SequenceOf<(Int, Seq.Generator.Element)> {
        var n = 0
        let nats = GeneratorOf { n++ }
        return SequenceOf(zip(nats, base))
}

for pair in myEnumerate(ys) {
    println(pair)
}

func all<Seq: SequenceType>(xs: Seq, pred: Seq.Generator.Element -> Bool) -> Bool {
    for x in xs {
        if !pred(x) { return false }
    }
    return true
}

func isOrdered<Seq: Sliceable where
    Seq.Generator.Element: Comparable,
    Seq.SubSlice.Generator.Element == Seq.Generator.Element>
    (xs: Seq) -> Bool {
        return isEmpty(xs) ||
            all(zip(xs, dropFirst(xs)),
                { $0.0 <= $0.1 })
}

func isOrdered2<Seq: Sliceable where Seq.Generator.Element: Comparable,
    Seq.SubSlice.Generator.Element == Seq.Generator.Element>
    (xs: Seq) -> Bool {
        if isEmpty(xs) { return true }
        for (prev, next) in zip(xs, dropFirst(xs)) {
            if prev > next { return false }
        }
        return true
}

func isOrdered3<Seq: SequenceType where
    Seq.Generator.Element: Comparable>(xs: Seq) -> Bool {
        var g = xs.generate()
        if var prev = g.next() {
            for curr in GeneratorSequence(g) {
                if prev > curr { return false }
                prev = curr
            }
        }
        return true
}



isOrdered2(xs)
isOrdered2([1,2,1])
isOrdered2([1,1,1])
isOrdered2([Int]())
