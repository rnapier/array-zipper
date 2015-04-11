//: Playground - noun: a place where people can play

let xs = [ 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 1]

let orderedxs2 = PermutationGenerator(elements: xs, indices: 0..<xs.count)
Array(orderedxs2)

let orderedxs = PermutationGenerator(
    elements: xs,
    indices: indices(xs))
Array(orderedxs)

let evenxs = PermutationGenerator(
    elements: xs,
    indices: stride(from: 0, to: xs.count, by: 2))
Array(evenxs)

let reversexs = PermutationGenerator(
    elements: xs,
    indices: reverse(indices(xs)))
Array(reversexs)

struct RepeatForever<C: CollectionType> : SequenceType, GeneratorType {
    let baseCollection: C
    var baseGenerator: C.Generator?

    init (_ baseCollection: C) {
        self.baseCollection = baseCollection
    }

    mutating func next() -> C.Generator.Element? {
        if let result = self.baseGenerator?.next() {
            return result
        } else {
            self.baseGenerator = self.baseCollection.generate()
            return self.baseGenerator?.next()
        }
    }

    func generate() -> RepeatForever {
        return self
    }
}

let _ : () = {
    var r = RepeatForever([1,2,3])
    r.next()
    var g = r.generate()
    g.next()
    }()

let _ : () = {
    let r = RepeatForever([1,2,3])
    var g = r.generate()
    g.next() // ==> 1
    var h = r.generate()
    h.next() // ==> 1

    g.next() // ==> 2
    g.next() // ==> 3

    h.next() // ==> 2

    }()


func f<G: GeneratorType>(g: G) {
    for x in GeneratorSequence(g) { }
    for x in SequenceOf({g}) { }

}