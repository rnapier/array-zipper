import Swift

let xs = [1,2,3,4,5]
let ys = ["one", "two", "three", "four", "five"]

for pair in zip(xs, ys) {
    print(pair)
}

let everyother = xs.enumerate()
    .filter { (i, v) in i % 2 == 0 }
    .map    { (_, v) in v }

func myEnumerate<Seq: SequenceType>(base: Seq)
    -> AnySequence<(Int, Seq.Generator.Element)> {
        var n = 0
        let nats = AnyGenerator<Int> {
            defer { n += 1 }
            return n
        }
        return AnySequence(zip(nats, base))
}

for pair in myEnumerate(ys) {
    print(pair)
}

func all<Seq: SequenceType>(xs: Seq, predicate: Seq.Generator.Element -> Bool) -> Bool {
    for x in xs {
        if !predicate(x) { return false }
    }
    return true
}

func isOrdered<Collection: CollectionType where
    Collection.Generator.Element: Comparable,
    Collection.Generator.Element == Collection.SubSequence.Generator.Element>
    (xs: Collection) -> Bool {

    return xs.isEmpty ||
        all(zip(xs, xs.dropFirst()), predicate:<=)
}

//func isOrdered2<Seq: Sliceable where Seq.Generator.Element: Comparable,
//    Seq.SubSlice.Generator.Element == Seq.Generator.Element>
//    (xs: Seq) -> Bool {
//    if isEmpty(xs) { return true }
//    for (prev, next) in zip(xs, dropFirst(xs)) {
//        if prev > next { return false }
//    }
//    return true
//}
//
//func isOrdered3<Seq: SequenceType where
//    Seq.Generator.Element: Comparable>(xs: Seq) -> Bool {
//    var g = xs.generate()
//    if var prev = g.next() {
//        for curr in GeneratorSequence(g) {
//            if prev > curr { return false }
//            prev = curr
//        }
//    }
//    return true
//}
//
//
//
//isOrdered2(xs)
//isOrdered2([1,2,1])
//isOrdered2([1,1,1])
//isOrdered2([Int]())
