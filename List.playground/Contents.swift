final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}

enum List<T> {
    case Cons(Box<T>, Box<List>)
    case Nil

    init(_ first: T, _ rest: List<T>) {
        self = Cons(Box(first), Box(rest))
    }
}

extension List {
    func first() -> T? {
        switch self {
        case let Cons(first, _): return first.value
        case Nil: return nil
        }
    }

    func rest() -> List<T> {
        switch self {
        case let Cons(_, rest): return rest.value
        case Nil: return .Nil
        }
    }
}

//extension List : SequenceType {
//    func generate() -> GeneratorOf<T> {
//        var node = self
//        return GeneratorOf {
//            let result = node.first()
//            node = node.rest()
//            return result
//        }
//    }
//}

//extension List : SequenceType {
//    func generate() -> IndexingGenerator<List> {
//        return IndexingGenerator(self)
//    }
//}

extension List : SequenceType {
    func generate() -> GeneratorOf<T> {
        var node = self
        return GeneratorOf {
            switch node {
            case let .Cons(first, rest):
                node = rest.value
                return first.value
            case .Nil:
                return nil
            }
        }
    }
}


// Integer indexing
extension List {
    subscript (i: Int) -> T? {
        return self.nth(i).first()
    }
    func nth (i: Int) -> List {
        var node = self
        for _ in 0 ..< i { node = node.rest() }
        return node
    }
}

struct ListIndex<T> {
    static var End: ListIndex<T> {
        return ListIndex(node: .Nil, offset: -1)
    }
    static func Start(list: List<T>) -> ListIndex<T> {
        return ListIndex(node: list, offset: 0)
    }

    let node: List<T>
    let offset: Int
}

extension ListIndex : ForwardIndexType {
    func successor() -> ListIndex {
        let rest = self.node.rest()
        switch rest {
        case .Cons: return ListIndex(node: rest, offset: self.offset + 1)
        case .Nil: return .End
        }
    }
}

func == <T>(lhs: ListIndex<T>, rhs: ListIndex<T>) -> Bool {
    return lhs.offset == rhs.offset
}

extension ListIndex : Printable {
    var description : String {
        return "(\(self.node), \(self.offset))"
    }
}

extension List : CollectionType {
    typealias Index = ListIndex<T>
    var startIndex: Index { return .Start(self) }
    var endIndex: Index { return .End }

    subscript (i: Index) -> T {
        return i.node.first()!
    }
}

extension List : Printable {
    var description : String {
        return "\(Array(self))"
    }
}

extension List {
    init<G: GeneratorType where G.Element == T>(var generator: G) {
        self = generator.next().map
            { Cons(Box($0), Box(List(generator: generator))) }
            ?? .Nil
    }

    init<S: SequenceType where S.Generator.Element == T>(elements: S) {
        self = List(generator: elements.generate())
    }
}

struct ListSlice<T> {
    let list: List<T>
    let bounds: Range<List<T>.Index>
    func first() -> T? { return self.startIndex.node.first() }
    func rest() -> List<T> { return self.startIndex.node.rest() }
}

extension ListSlice : CollectionType {
    typealias Index = List<T>.Index
    var startIndex: Index { return self.bounds.startIndex }
    var endIndex: Index { return self.bounds.endIndex }
    subscript (i: Index) -> T { return i.node.first()! }
    func generate() -> IndexingGenerator<ListSlice> {
        return IndexingGenerator(self)
    }
}

extension ListSlice : Sliceable {
    typealias SubSlice = ListSlice<T>
    subscript (bounds: Range<Index>) -> ListSlice<T> {
        return ListSlice(list: self.list, bounds: bounds)
    }
}

extension ListSlice : Printable {
    var description : String {
        return "\(Array(self))"
    }
}

extension List : Sliceable {
    typealias SubSlice = ListSlice<T>
    subscript (bounds: Range<Index>) -> ListSlice<T> {
        return ListSlice(list: self, bounds: bounds)
    }
}

let z = List(elements: [1,2,3])
for x in z { println(x) }

let l = List(1, List(2, List(3, .Nil)))
l.description
for x in l {
    println(x)
}

for x in zip(l, indices(l)) { println(x) }

l[1]

let m = List(10, List(20, .Nil))
let i = find(l, 2)!
m[i]

Array(l)

dropFirst(l).first()
println(dropFirst(l).rest())
println(dropFirst(l))
//println(l[1..<2])
