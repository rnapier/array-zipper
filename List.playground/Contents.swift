import Swift

enum List<Element> {
    indirect case Cons(Element, List)
    case Nil

    init(_ first: Element, _ rest: List<Element>) {
        self = Cons(first, rest)
    }

    var rest: List<Element> {
        switch self {
        case let .Cons(_, rest): return rest
        case .Nil: return .Nil
        }
    }
}

extension List : SequenceType {
    func generate() -> AnyGenerator<Element> {
        var node = self
        return AnyGenerator {
            switch node {
            case let .Cons(first, rest):
                node = rest
                return first
            case .Nil:
                return nil
            }
        }
    }
}

struct ListIndex<Element> {
    static var End: ListIndex<Element> {
        return ListIndex(node: .Nil, offset: -1)
    }
    static func Start(list: List<Element>) -> ListIndex<Element> {
        return ListIndex(node: list, offset: 0)
    }

    let node: List<Element>
    let offset: Int
}

extension ListIndex : ForwardIndexType {
    func successor() -> ListIndex {
        let rest = self.node.rest
        switch rest {
        case .Cons: return ListIndex(node: rest, offset: self.offset + 1)
        case .Nil: return .End
        }
    }
}

func == <T>(lhs: ListIndex<T>, rhs: ListIndex<T>) -> Bool {
    return lhs.offset == rhs.offset
}

extension ListIndex : CustomStringConvertible {
    var description : String {
        return "(\(self.node), \(self.offset))"
    }
}

extension List : CollectionType {
    typealias Index = ListIndex<Element>
    var startIndex: Index { return .Start(self) }
    var endIndex: Index { return .End }

    subscript (i: Index) -> Element {
        return i.node.first!
    }
}

extension List : CustomStringConvertible {
    var description : String {
        // FIXME: Creates an infinite loop in Playgrounds (not live code) in Xcode 7.3collecti
        //        return("\(Array(self))")
        return "LIST"
    }
}

extension List {
    init<G: GeneratorType where G.Element == Element>(generator: G) {
        var g = generator
        self = g.next().map
            { Cons($0, List(generator: g)) }
            ?? .Nil
    }

    init<S: SequenceType where S.Generator.Element == Element>(elements: S) {
        self = List(generator: elements.generate())
    }
}

let z = List(elements: [1,2,3])
var g = z.generate()
g.next()
let x = Array(z)

for x in z {
    print(x)
}


let l = List(1, List(2, List(3, .Nil)))

l.description
for x in l {
    print(x)
}

for x in zip(l, l.indices) { print(x) }

let m = List(10, List(20, .Nil))
let i = l.indexOf(2)!
m[i]


l.dropFirst().first
print(l.dropFirst().dropFirst())
print(l.dropFirst())

extension List {
    subscript(offset i: Int) -> Element? {
        return self.dropFirst(i).first
    }
}
