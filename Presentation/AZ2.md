## Array To Zipper
### Rob Napier

---

## Array
## Dictionary
## String
## Set

^Array. Sure. Dictionary. Check. String. Of course. Set. Nice to meet you.

---

## SequenceType
## CollectionType
## Strideable
## Slice
## GeneratorType

^ Sequence. Collection. Those sound useful. Stride. Slice. Generator. I guess I've heard of those those before....

---

## Zip2Generator
## LazyMapSequence
## AnyBidirectionalCollection
## ReverseRandomAccessCollection

^ Zip2Generator. LazyMapSequence? AnyBidirectionalCollection? ReverseRandomAccessCollection. OK, this is getting a little silly.

---

## ExtendedGraphemeClusterLiteralConvertible

^ ExtendedGraphemeClusterLiteralConvertible. Now you're just messing with us.

^ Actually I am. We're not going to talk about that one. Today we're mostly going to talk about collections, well sequences. Well... mostly things you can generate and maybe a few other things. It'll make more sense as we go along.

---

Stdlib includes the obvious

```swift
/// `Array` is an efficient, tail-growable random-access
/// collection of arbitrary elements.
public struct Array { ... }
```

Alongside the obscure

```swift
/// A common base class for classes that need to be non-`@objc`,
/// recognizably in the type system.
public class NonObjectiveCBase { ... }
```

^ The Swift standard library is chock full of types without a good bestiary. The header mixes together things you use every day with types you probably should never touch. So how do you make sense of it all? 

---

## Generators

^ Well, let's start at the bottom, and we'll work our way up from there. Let's look at Generators.

---

## Generators

* Encapsulate iteration state
* Provide the next element if there is one

```swift
public protocol GeneratorType {
    associatedtype Element
    public mutating func next() -> Self.Element?
}
```

^ A generator can do just one thing: it can give you the next element if there is one. 

---

```swift
struct MyEmptyGenerator<Element> : GeneratorType {
    mutating func next() -> Element? {
        return nil
    }
}

var e = MyEmptyGenerator<Int>()
e.next()
e.next()
```

^ Let's build the simplest possible generator. The empty generator. Swift already provides this one, but let's build it ourselves.

^ That's as simple as they get. We just return nil and nil means we're done.

^ Notice that I declared `e` as `var`? That's on purpose and it's required. Generators encapsulate state, so they have to be mutable. 

> Generators are mutable so no else has to be.

---

```swift
struct MyGeneratorOfOne<Element> : GeneratorType {
    var element: Element?
    init(_ element: Element?) { self.element = element }

    mutating func next() -> Element? {
        defer { element = nil }
        return element
    }
}
```

^ OK, let's make it a little more interesting. Let's return exactly one element.

---

```swift
struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        defer { n += 1 }
        return n
    }
}

var nats = NaturalGenerator()
```

^ How about something that Swift doesn't give us? Let's build a generator of all the natural numbers starting at 0. We have some internal state, `n`, and we increment it every time `next()` is called. Note again how generators are inherently stateful and mutable. You're probably never going to encounter a `let` generator. That wouldn't really make sense.

^ Notice also that this generator never intentionally ends. It can keep creating values forever as long as you keep calling `next()`. Of course there's a limit on the size of `Int`, but this generator behaves like there isn't. It'll just overflow if you increment it too many times. There's nothing about a generator that says it has to be finite.

---

```swift
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
```

^ There's nothing about a generator that says it has to be deterministic or repeatable. This is a perfectly fine generator of a finite set of random numbers. A generator could pull packets from the network, or elements from an array. Generators just generate values.

^ Questions?

---

## Generic Generators

^ Sometimes you want to generate something new, but creating a whole new type is more trouble than it's worth. For a really simple generator, sometimes you'd rather just define it inline when you need it.

---

```swift
struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        defer { n += 1 }
        return n
    }
}
var nats = NaturalGenerator()
```

^ That Natural Number generator we created was really simple. All we really need is that `next()` function. It'd be nice if there were a generic generator that we could just pass that function to.

---

^ And of course there is. It's called `AnyGenerator`. With that, we could make our Natural generator this way. We just pass a closure and capture a local variable. We'll be seeing `AnyGenerator` several times today, so it's good understand what's happening here.

```swift
struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        defer { n += 1 }
        return n
    }
}

var nats = NaturalGenerator()
```

## :arrow_down:

```swift
var n = 0
var nats = AnyGenerator{
    defer { n += 1 }
    return n
}

```

---

```swift
public struct AnyGenerator<Element> : GeneratorType {
    public init<G : GeneratorType where G.Element == Element>(_ base: G)
    public init(body: () -> Element?)
    ...
}
```

^ We can construct an AnyGenerator two ways. We can either pass a `next()` function, or we can pass another generator. Passing another generator lets us hide the specific type we're using to generate values, and just expose "something that generates Element."

---

```swift
func makeNaturalGenerator() -> AnyGenerator<Int> {
    var n = 0
    return AnyGenerator{
        defer { n += 1 }
        return n
    }
}

func makeNaturalGenerator() -> AnyGenerator<Int> {
    return AnyGenerator(NaturalGenerator())
}
```

^ So we can wrap up our natural generator as just a next() function, or we could type-erase our internal struct so we don't have to expose it.

---

## Sequences

^ Let's move up one level in the stack from Generator to Sequence.

---

## Sequences

* Can be iterated by `for...in`
* Wraps a Generator

^ A Sequence is just a series of values, like an old stock ticker tape. You start at the beginning of the tape, and you look at the value there. And then you can look at the next value, and the next one. You can't go backwards, and you don't know if the tape ever ends. It's just a sequence of values.

^ All Sequence really does is wrap a generator and let you iterate with a for...in loop. It doesn't promise anything else.

^ But unlike a generator, Sequences can be immutable. They don't maintain their iteration state. That's left to the generator. They just represent the series of values.

```swift
protocol SequenceType {
    associatedtype Generator : GeneratorType
    func generate() -> Generator
}
```

^ Here's the heart of the protocol. It needs a generator type and a way to create the generator. That's it. The protocol technically has other requirements, but in most cases you'll use the default implementations.

---

^ It may not be possible to iterate over a sequence more than once. This can surprise you sometimes. For example, consider this function.

## Danger ahead

```swift
func withoutMinMax<Seq: SequenceType
    where Seq.Generator.Element : Comparable>
    (xs: Seq) -> [Seq.Generator.Element]{

    guard let
        mn = xs.minElement(),
        mx = xs.maxElement()
        else { return [] }

    return xs.filter { $0 != mn && $0 != mx }
}
```

^ Seems fine, but it's poorly defined behavior. It iterates over xs three times. Once in minElement, once in maxElement, and once in filter. There's no promise you can do that. If you want to be able to iterate more than once, you need to use a Collection, or as Apple sometimes says, "have static knowledge that the sequence is multipass."

---

```swift
struct MyEmptySequence<Element> : SequenceType {
    func generate() -> EmptyGenerator<Element> {
        return EmptyGenerator()
    }
}

for x in MyEmptySequence<Int>() {
    fatalError("This should never run")
}
```

^ Even so, sequences are useful. Let's build a few. We'll start again with the empty sequence.

^ All we need a function that returns a new generator. We can reuse Swift's built-in EmptyGenerator, and we're done.

---

```swift
struct NaturalSequence : SequenceType {
    func generate() -> AnyGenerator<Int> {
        var n = 0
        return AnyGenerator{
            defer { n += 1 }
            return n
        }
    }
}
```

^ Many of the sequences in stdlib have their own specialized generators, but you often can just use a generic generator and not create a new type. This is a really common use of AnyGenerator.

---

```swift
let nats = AnySequence { () -> AnyGenerator<Int> in
    var n = 0
    return AnyGenerator {
        defer { n += 1 }
        return n
    }
}
```

^ And like AnyGenerator, there's a generic Sequence called AnySequence. It lets you wrap an arbitrary generate method as sequence. And like AnyGenerator, you can pass a sequence to AnySequence to type-erase it.

---

### Infinite sequences

```swift
func myCount<Seq: SequenceType>(xs: Seq) -> Int {
    return xs.reduce(0) { (n, _) in n + 1 }
}
```

^ Besides multi-pass, you also have to remember that sequences can be infinite. The "nats" sequence we created earlier was infinite.

^ The problem of multipass and possibly-infinite sequences leads to an interesting version of counting. You might be tempted to write a `count` function on `Sequence` like this one.

^ OK, maybe you'd never write a `count` function that way, maybe you'd write it this way:

---

### Infinite sequences

```swift
func myCount<Seq: SequenceType>(xs: Seq) -> Int {
    var n = 0
    for _ in xs { n += 1 }
    return n
}
```

^ And that's fine, too, but Swift doesn't provide this. Counting a sequence might consume the sequence, which is generally going to be unhelpful.

---

```swift
extension SequenceType {
    public func underestimateCount() -> Int
}
```

^ Instead, it provides `underestimateCount`, which promises not to consume any of your elements. If you pass it a collection, like an array, you'll get its length, but if you pass an unknown sequence type, it'll return 0. So that can be handy if you want to preallocate space when you can, but accept that sometimes you can't know how much.

---

## Collections

^ We've kind of talked this multipass problem to death now, but it has a big impact on stdlib. It means that often the preferred type is Collection, not Sequence, since a Collection is always multipass. So let's talk about Collection for a while.

^ If you've ever worked in a functional language, you probably are used to something like Sequence being the go-to type for building algorithms. But in Swift, the type you often need is Collection. Its just much more flexible than Sequence.

---

### Collections

* Conforms to Indexable and SequenceType
* Multipass
* Efficient subscript using some index
* Iterates in subscript order

^ A Collection is a multi-pass sequence, and it's indexable. That means you can use subscripts to efficiently fetch elements.

^ Now indexes use a subscript, not all subscripts are indexes. Subscripts are just syntax.

---

```swift
struct Random {
    subscript (n : UInt32) -> UInt32 {
        return arc4random_uniform(n)
    }
}

let r = Random()
r[100]  // 51
r[1000] // 872
r[100]  // 10
```

^ We could implement a random number generator using subscripting. But this isn't a collection.

^ Subscripting doesn't make it a collection. As long as a collection doesn't mutate, it should return the same values for the same indexes.

^ And those indexes should always be in the same order for a given instance. And collections need to subscript on their index in O(1).

---

### Start with Sequence

```swift
struct MyEmptySequence<Element> : SequenceType {
    func generate() -> EmptyGenerator<Element> {
        return EmptyGenerator()
    }
}
```

^ Let's build some collections, and you'll see what I mean. We'll start with our EmptySequence and upgrade it to a collection.

---
### Upgrade to Collection

```swift
struct MyEmptyCollection<Element> : CollectionType {
    func generate() -> EmptyGenerator<Element> {
        return EmptyGenerator()
    }
}
```

---

### Index

```swift
struct MyEmptyCollection<Element> : CollectionType {
    func generate() -> EmptyGenerator<Element> {
        return EmptyGenerator()
    }
    typealias Index = Int    
}
```

^ We need to define an index type. Since this collection is empty, it doesn't really matter what the index type is, so we'll use something simple like `Int`.

---

### Start and end

```swift
struct MyEmptyCollection<Element> : CollectionType {
    func generate() -> EmptyGenerator<Element> {
        return EmptyGenerator()
    }
    typealias Index = Int
    let startIndex = 0
    let endIndex = 0
}
```

^ Then we need to add a start and end index. The start index is pretty obvious. The end index is one past the final value. If the start and end indexes are the same, the collection is empty.

---

### Subscript

```swift
struct MyEmptyCollection<Element> : CollectionType {
    func generate() -> EmptyGenerator<Element> {
        return EmptyGenerator()
    }
    typealias Index = Int
    let startIndex = 0
    let endIndex = 0    
    subscript (position: Index) -> Element {
        fatalError("Out of bounds")
    }
}
```

^ And finally, there needs to be a way to subscript using your chosen index type. That's the minimum requirements to be a collection.

---

## Linked List

```swift
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
let l = List(1, List(2, List(3, .Nil)))
```

![right fit](Cons.pdf)

^ Let's make a little more interesting collection. How about a linked list? Making this into a collection is actually a little complicated, so don't worry if you don't immediately follow every step. When we're done, you should just have a feel for how all the parts work together so you know what you need to think about when designing new Collections. Or maybe why you'd rather avoid it.

^ Here's our basic structure. It's not a sequence or collection. It's just a simple list made up of Cons cells and Nil at the end. Cons is just an old Lisp term for an element and a "next" pointer. So we can build it up by passing a 1, followed by a list with a 2, followed list with a 3, followed by Nil. Like I say, this is a really common way to build a linked list.

^ Notice that `indirect` keyword on Cons. If you tried building data structures like this in the early days of Swift, you probably discovered that you needed this annoying Box type to make it work. But now we can make recursive value types just by adding `indirect`.

^ Also notice that I've defined `rest` here, but not `first`. We'll talk about that in a minute.

---

```swift
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
```

^ First, let's make this a Sequence so we can iterate over it. That means we just need to implement generate()

^ That's pretty straightforward. Start at the current node, and every time the next node is asked for, move forward.

---

### Subsequences

```swift
func dropFirst(n: Int) -> Self.SubSequence
func dropLast(n: Int) -> Self.SubSequence
func prefix(maxLength: Int) -> Self.SubSequence
func suffix(maxLength: Int) -> Self.SubSequence
```

^ Sequences have a subsequence type. By default, these return an AnySequence that iterates over the base sequence. Now, if you've used linked lists before, you might be thinking "can't List be its own SubSequence?" And it *could*, but it's probably a bad idea. Generally SubSequences should be efficient to create out of a sequence, but you can't efficiently slice a List into a smaller List except at the head. dropFirst would be really easy to implement, but dropLast would require that we rewrite the entire list since every element includes its entire tail.

^ Does this make sense? This is a really common kind of problem in Swift. Data structures that seem quite simple turn out to have many subtle details and you need to think about them very carefully. 

---

```swift
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
let l = List(1, List(2, List(3, .Nil)))
```

^ This is why I defined `rest` as part of the type itself. This lets you slice the list from the head efficiently without forcing us to deal with the problems of trying to make List its own SubSequence. Maybe this makes it clearer why Swift has SubSequences. Sometimes you can efficiently slice things to themselves and sometimes you can't.


^ But I didn't have to define `first`. The default implementation of `first` works fine. It calls `generate` and then calls `next` one time. So we get that for free.

^ Anyway, SubSequences can be a little tricky. And that brings us around to the next thing that can be very tricky: Indexes.

---

### Index design

* Store iteration state: Cursor
* Efficient access

^ We'd like to make List a Collection, and to do that we need an index that we can use to save our state while iterating. I really want you to think about it that way. The Index isn't the way you fetch a value out of a collection. It's how you save your iteration state.

^ What's that mean? It means that nine times out of ten, your Index isn't going to be an integer. We all look at Array, and it has this simple integer index, and we think oh! that's what an index is. But if you look through stdlib, you'll note that most collections use something other than Int as their index.

^ The key requirement is that subscripting by the index should be O(1). If you have the index, you should be able to jump right back to where you were when you fetched it. Computing the startIndex and endIndex should also be O(1).

^ Note that this is something likely to change in Swift 3. Saving the iteration state inside the index has turned out to be a bit awkward, and in the future indexes will probably be simpler. But at least for a few more months, this is how it works.

---

### Types of Index

* `ForwardIndexType` :arrow_right: Can only move forward
* `BidirectionalIndexType` :arrow_right: Can move forward or backward
* `RandomAccessIndexType` :arrow_right: Can jump to any index

^ There are three kinds of indexes. Forward indexes can only move forward. Our linked list is like that. Given a location in the list, we can move forward easily, but we can't move backward. These are the simplest to implement. They just have a `successor` method.

^ A bidirectional index is like a doubly linked list. Given a location in the list, we can move forward or we can move backward. But there's no way to jump immediately to the third element. We have to start somewhere and move forward twice to get there. String views have bidirectional indexes.

^ A random access index can jump to any element instantly without having to access other indexes first. The most common random access indexes are integers. I can ask for the third element of an array without asking for the first and second. They're much more complicated than the other indexes, and most of the time you're not going to build one; you'll just use integers.

^ Today we're just going to focus on the simplest form, the forward index.

---

^ Let's start with how we shouldn't do it. We shouldn't use an Int:

## Integer Subscripting
### Not a good List index

```swift
extension List {
    subscript (i: Int) -> Element? {
        return nth(i).first
    }
    func nth(i: Int) -> List {
        var node = self
        for _ in 0 ..< i { node = node.rest }
        return node
    }
}
```

^ This is a really useful subscript. There's nothing wrong with this subscript. It's just not useful as an Index. This subscript is O(n). Collection algorithms may put index lookups in a loop, so that's O(n^2), which can really quickly become a problem. You'll also notice that this subscript returns an optional. You're free to do that in your subscripts. But the one you use for Collection has to return your element type. So that's no good.

---

### Indexes

* Need to remember the current iteration location
* Must be able to increment
* Must be able to compare for equality

^ What else could we use? Well, we want something that saves our place in our iteration, and can be used to move forward, and that we can test for equality.

^ The List itself handles the first two items easily. It include a pointer to our current position, and a pointer to our next position. The problem is equality checking. Saying that two lists are equal really means walking over the two lists and comparing their elements. That's too time consuming for an index equality check, which needs to be efficient. We can't compare the elements anyway, since List doesn't require its element to be Equatable.

---

## A proper List index

```swift
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
```

^ Here's one way to do it. We keep track of the list, which is really our iteration state. And then we add an offset to give us something to compare for equality. Our rule is that if two offsets are equal, then the indexes are equal.

---

```swift
extension ListIndex : ForwardIndexType {
    func successor() -> ListIndex {
        let rest = node.rest
        switch rest {
        case .Cons: 
            return ListIndex(node: rest, index: index + 1)
        case .Nil:
            return .End
        }
    }
}

func == <Element>(lhs: ListIndex<Element>, 
                  rhs: ListIndex<Element>) -> Bool {
    return lhs.index == rhs.index
}
```

^ So how do we implement ForwardIndexType? We need a successor and an equals. For successor, we look at the next element, and if it's not the end of the list, we return a new ListIndex with the next element, and we bump the offset by one to make it unique.

---

![fit](IterateList.pdf)

^ For equality, we just compare the offset values. Don't let that integer confuse you. It's not really the offset from the "start" of the list. There's no such thing, really. That's not how lists work. It's the offset from the start of an iteration over the list. So if I start iterating from element 1, then the offsets count up from there, starting at 0, and then go to -1 at the end. If I start iterating from element 2, then the offsets start counting up from there, starting at 0, and then go to -1 at the end. These integers are just internal implementation details to let us compare two indexes from the same iteration.

^ And since our indexes are only equatable, not comparable, offset -1 isn't "less than" offset 0. They're just not equal.

^ Make sense? Like I said, this will probably get much simpler in Swift 3.

---

## Now make it a Collection

```swift
extension List : CollectionType {
    typealias Index = ListIndex<Element>
    var startIndex: Index { return .Start(self) }
    var endIndex: Index { return .End }

    subscript (i: Index) -> Element {
        return i.node.first!
    }
}
```

^ That's all we need. Now `ListIndex` is a valid `ForwardIndexType`. How do we fit it into our collection?

^ We need a startIndex. That's always the first cons cell, which is `self`, and an offset of 0.

^ We need an endIndex. That's the index one past the last element, and we use a consistent marker for that called .End with a node of .Nil and an offset of -1.

^ Notice that we don't need to know how far apart startIndex and endIndex are. You don't have to be able to do math on these values. It's ok that counting the elements is O(n), as long as you can jump to any place you've visited before in O(1).

^ And last we have the required subscript function. It just extracts the value at that index. And subscripting at the endIndex will crash. That's expected. endIndex is one *past* the end of the list.

---

^ Now that we have a collection, we get a bunch of helpers automatically, which is really why we bother in the first place.

## We get a bunch of helpers

```
public func prefixUpTo(end: Self.Index) -> Self.SubSequence
public func suffixFrom(start: Self.Index) -> Self.SubSequence
public func prefixThrough(position: Self.Index) -> Self.SubSequence
public var isEmpty: Bool { get }
public var count: Self.Index.Distance { get }
public var first: Self.Generator.Element? { get }
public func map<T>(@noescape transform: (Self.Generator.Element) throws -> T) rethrows -> [T]
public func dropFirst(n: Int) -> Self.SubSequence
public func dropLast(n: Int) -> Self.SubSequence
public func prefix(maxLength: Int) -> Self.SubSequence
public func suffix(maxLength: Int) -> Self.SubSequence
public func prefixUpTo(end: Self.Index) -> Self.SubSequence
public func suffixFrom(start: Self.Index) -> Self.SubSequence
public func prefixThrough(position: Self.Index) -> Self.SubSequence
public func indexOf(predicate: (Self.Generator.Element) throws -> Bool) rethrows -> Self.Index?
public var indices: Range<Self.Index> { get }
public var lazy: LazyCollection<Self> { get }
...
```

---

## Slices

* Implements CollectionType
* A sub-range of elements can be efficiently extracted
* Slices should be temporary
* Get Slice for free, but may want to create your own

^ Becoming a Collection also changes our SubSequence from AnySequence to Slice.

^ Slices are a struct, just like AnySequence. If you remember the old "Sliceable" protocol, that's gone, and things have gotten a lot simpler.

^ Slices are efficient because they don't copy elements. They just forward requests to the underlying data.

^ But that means a slice retains the whole underlying collection. If you have a million-entry list, and you slice out the first ten elements, the whole list stays around. So slices should be temporary. You usually don't want to store them in properties without copying them to a smaller collection.

^ If you don't define a SubSequence, you'll get Slice for free. It just forwards requests to the underlying data. But if you have specialized storage, you may be able to make a more efficient SubSequence. Array does this with its special ArraySlice. The fact that a subsequence of Array is an ArraySlice is one reason to write your functions to work with CollectionType rather than Array when you can.

---

## Concrete Types

^ Now that we've discussed the protocols, let's talk about some concrete types that implement them.

---

### Array

^ Array is probably the most important collection in Swift, and it's surprisingly subtle. Studying Array gives a lot of insight into how the Swift team thinks and what's important to them.

* Predictable performance for "normal" usage
* Transparent interoperability with NSArray
* Local-mutation / Non-sharing

---

### Predictable performance for "normal" usage

* "Normal" is like C++ std::vector
(not Haskell, Scala, ObjC, ...)
* Subscript is O(1)
* Append is O(1), prepend/insert is O(n)

^ Performance, and predictable performance, are clearly front-of-mind in stdlib. Many stdlib classes and methods give complexity guarantees, just like STL in C++. Foundation never did that. NSArray gives very few promises on how efficient operations are, and NSArray's performance characteristics are kind of surprising to Java and C++ developers. NSArray is optimized for random insertions. Swift's Array is optimized for appending.

^ And I want to be really clear that what Swift optimizes for isn't the obvious answer. In lots of languages, Haskell, ML, Scala, it's much faster to prepend than to append. So this gives an interesting insight into who the Swift team is trying to appeal to and what they consider "normal" behaviors.

---

### Transparent interoperability

* Sometimes Array is really NSArray
* Sometimes it isn't
* Sometimes it can convert without copy
* Sometimes it can't

^ There are a lot of interesting tradeoffs that happen where NSArray and Array touch, and tradeoffs are where you see what's important. The performance of NSArray is very different from Array. So Swift could require an element-by-element copy of the NSArray into a Swift data structure during bridging so that it could make promises about the performance. Sometimes C++ does that kind of thing because its performance promises are part of the STL spec. But in Swift, the approach is "well, I know we promised Array would behave a certain way, but sometimes it won't because it's really an NSArray."

---

### ContiguousArray

* Promises to really, really have Swift Array performance
* Loses bridging to ObjC

^ This makes things much faster. It avoids unneeded copies. But it does mean that performance may surprise you. So the Swift team knew this, and gave an out: `ContiguousArray`. It's just like an Array, but it doesn't bridge to ObjC, so it always has predictable performance. This kind of pragmatism shows up all over Swift. It's inconsistent. It's somewhat inelegant. But in the vast majority of programs it works just fine and gives you a way to fix it when it doesn't.

^ Speaking of inconsistent, ContiguousArray is fairly tricky, and you should avoid using it unless you really need it. There are a few magical language features that Arrays get that ContinguousArrays don't. For example, Arrays automatically bridge to C code that expect a pointer. If you try to use a ContiguousArray the same way, it may not bridge correctly and you may corrupt your data structures. True story.

---

### Operations on Sequences

* map - Convert one sequence to a same-sized sequence
* filter - Select items from a sequence
* flatMap - map + filter
* reduce - Convert a sequence to a single value

^ Swift offers several tools from the FP world for manipulating sequences.

---

```swift
let xs = [3, 1, 4, 1, 5, 9, 2, 6, 5]

let doublexs = xs.map { $0 * 2 }

let smallxs = xs.filter { $0 < 10 }

let smalldoublexs = xs
        .map { $0 * 2 }
        .filter { $0 < 10 }
        
let smalldoublexs2: [Int] = xs.flatMap {
    let result = $0 * 2
    return result < 10 ? result : nil
}

let sum = xs.reduce(0, combine: +)
```

---

## Laziness

```swift
let xs = [3, 1, 4, 1, 5, 9, 2, 6, 5]
let doublexs = xs.map { $0 * 2 }
let doubleSecond = doublexs[1]
```

^ In Swift, Array's `map` method applies the function to every element of the array, and creates a new array with those values. So this code has to perform 16 multiplications, plus allocate memory for 16 values. We then only access one of those values and throw the rest away. We call this approach "strict." It executes the function exactly once for every element, no matter what.

---

^ In this case, that's a small waste of time and space, but imagine if this array had tens of thousands of elements. Even if we needed all the results, the cost of allocating temporary space for them all could be nontrivial. For example:

## Mapping too soon

```swift
for x in xs.map(f) {
	print(x)
}
```

---

^ Creating a huge temporary array of transformed values here would be a huge waste of time and memory. Of course we could just write it like this:

## Mapping too soon (fix)

```swift
for x in xs {
	print(f(x))
}
```

---

^ But what about this case:

## Map/filter chains

```swift
let smalldoublexs = xs
    .map { $0 * 2 }
    .filter { $0 < 10 }
```

^ The call to `map()` would allocate an temporary array as big as xs. Then the call to filter would allocate another array. If you have a chain of maps and filters on a large array, the cost of all these intermediate arrays can be substantial.

---

^ So what can we do about it? We discussed flatMap before, but we can also use laziness.

## Map/filter chains (fix)

```swift
let smalldoublexs = Array(xs.lazy
    .map { $0 * 2 }
    .filter { $0 < 10 }
)
```

^ Each element is completely processed before being put into the final result. Wrapping it in Array constructor makes sure everything is calculated and we're left with an array rather than a lazy sequence. We can think of strict versus lazy as horizontal versus vertical.

^ There used to be an `array` property that you could use to convert a lazy sequence back to an Array, but it was removed and now you're supposed to use the `Array` constructor. I'm not certain why that change was made; I find it kind of ugly, but it was definitely on purpose, so this is the way I handle it.

---

### FP and Performance

```swift
// O(n)
func addOne(xs: [Int]) -> [Int] {
    return xs + [1]
}

// O(1)
func addOne(inout xs: [Int]) {
    xs.append(1)
}
```

^ Swift offers some FP tools, but that doesn't make a functional language. Immutable data structures can be very expensive in Swift.

---

```swift
// O(n^2), and crashes for n > ~100k
func ones(n: Int) -> [Int] {
    if n == 0 { return [] }
    return [1] + ones(n - 1)
}

// O(n^2) (but faster than recursion)
func ones(n: Int) -> [Int] {
    return (1...n).reduce([]) { (a, _) in a + [1] }
}

// O(n)
func ones(n: Int) -> [Int] {
    var result: [Int] = []
    for _ in 1...n { result.append(1) }
    return result
}
```

^ This it often means recursion is really expensive. And `reduce` is a horrible way to build arrays.

---

### BUT...

```swift
// Loop O(n)
func ones(n: Int) -> [Int] {
    var result: [Int] = []
    // result.reserveCapacity(n) // Helps, but not as much as map
    for _ in 1...n { result.append(1) }
    return result
}

// Map O(n) and ~ 3x faster
func ones(n: Int) -> [Int] {
    return (1...n).map{ _ in 1 }
}
```

^ That said, in my benchmarks, `map` blows the loop away. You can speed up the loop if you remember to call reserveCapacity first, but the map is still much faster.

---

```swift
  public func map<T>(
    @noescape transform: (Generator.Element) throws -> T
  ) rethrows -> [T] {
    let count: Int = numericCast(self.count)
    if count == 0 {
      return []
    }

    var result = ContiguousArray<T>()
    result.reserveCapacity(count)

    var i = self.startIndex

    for _ in 0..<count {
      result.append(try transform(self[i]))
      i = i.successor()
    }

    _expectEnd(i, self)
    return Array(result)
  }
```

^ But why isn't my loop as fast as map? Well, map is quite a bit more complicated. This is a great example of the power of higher-order functions.

---

### The takeaway

* Simple map/filter/flatMap are elegant, often faster than loops
* Chains of map, filter, flatMap usually need lazy
* If it's not trivially convertible to map/filter/flatMap, use a loop
* reduce is a sometimes food

^ So what's the take away? Well first, I think `map` is very good Swift and you should learn to use it well. If you're converting one sequence into another sequence, map, flatMap, and filter are fantastic tools and very optimized as long as you know when to make them lazy.

^ Conversely, recursion is often not good Swift, and reduce is a sometimes food. Frankly, the only use I've had for reduce in real Swift is for summing a list. And I say this as someone who really enjoys coming up with clever ways to use it in functional languages. It just isn't a big part of Swift.

---

### Numbers

```swift
struct Int : SignedIntegerType, ... { ... }

struct Double : FloatingPointType, ... { ... }
```

^ Numbers are structs. Structs? Really? Isn't that expensive for something so basic? This is a great example of an often-overlooked feature of Swift. Structs are zero-overhead. There is no metadata stored in a struct the way there is in a class. So a struct containing an integer requires exactly the storage of the integer.

---

### Integers vs. Floating Point

* Integers and floating point numbers are intentionally distinct

```swift
10 * 9 * 0.01 == 0.01 * 9 * 10  // false

let x = Float(100_000_000)
x == x + 1  // true

let y = 0.0 / 0
1 <= y  // false
1 >= y  // false
y == y  // false
```

^ It is very difficult to write functions that take "a number" in Swift. This is a mix of intent and current limitations. On the intent side, there are many subtle differences between floating point numbers and integers that can lead to bugs if you ignore. For example, floating point numbers can accumulate rounding errors so that things that look equal aren't. The gaps between valid floating point values can be greater than one, so incrementing them for loops can fail. And there are floating point values that can't be compared to other values. Even the basic idea that x equals x can fail when you're dealing with floating point. You really do need to think differently when working in floating point, and Swift encourages you do to that and avoid subtle bugs.

---

### Promotion

* Basic rule: Swift doesn't auto-convert anything

```swift
Int32(1) == Int64(1) 
         // binary operator '==' cannot be applied to operands of type 'Int32' and 'Int64'
         
Float(0.1) == Double(0.1)  // Hmmmm.... should it? Should 0.33 == 0.3333?
```

^ Swift also doesn't promote values to wider types automatically, like from 32-bit to 64-bit. For integers, this is a mix of performance concerns and language limitations. Promoting values can introduce significant performance costs that you should probably be aware of, but the bigger issue is probably that the compiler has a lot of trouble with figuring out expressions that include a lot of possible promotions. That's the kind of thing that leads to "expression too complicated" errors. It's possible this will improve in the future. I think the failure to promote 32-bit integers to 64-bit integers is mostly "it's hard to get the compiler to do that."

^ For floating point, however, the issues are much more subtle. First, the performance issues can be much more significant. Swift wants to be portable to many platforms, and some platforms have dramatically different float and double performance. Automatically promoting could hide multiple-order-of-magnitude performance issues. But even if performance weren't an issue, extending floating point values to more decimal places introduces errors that can be surprising. In binary, 0.1 is a repeating decimal. So when you promote a float 0.1 to double, the value you get will be significantly different than the double version of 0.1. Hiding that in an implicit promotion can make it very hard to track down the resulting bugs.

^ Even so, the Swift team does seem to want to make float to double conversion work. But they clearly want to be very careful with it. I don't expect to see changes here soon.

---

### CGFloat ... yeah, so that

^ Which brings us to `CGFloat`, which is really annoying in Swift because you wind up manually convert it to and from other floating point types. Yeah. That's frustrating, and I have no idea how it's going to get better unless Cocoa just redefines CGFloat as Double. Moving on.

---

^ Strings are special. It's easy to assume they're collections, but they're not. They have various views that are collections, though.

### Strings

```swift
extension String {
	public struct UTF8View : CollectionType { ... }
	public struct UTF16View : CollectionType { ... }
	public struct CharacterView : CollectionType { ... }
	public struct UnicodeScalarView : CollectionType { ... }
}
```

^ Why the views? Because it's not really obvious what a string's element should be, and it's *really* not clear what the length should be.

---

```swift
let e = "é"             // "é"
e.utf8.count            // 2
e.utf16.count           // 1
e.unicodeScalars.count  // 1
e.characters.count      // 1
```

^ Something as simple an accented e already raises big questions about length vs. byte-encoding length. Let's try an emoji:

---

```swift
let face = "😠"
face.utf8.count            // 4
face.utf16.count           // 2
face.unicodeScalars.count  // 1
face.characters.count      // 1
```

^ That's even weirder. How about if we add skin tone.

---

``` swift
let tone = "👱🏾"
tone.utf8.count            // 8
tone.utf16.count           // 4
tone.unicodeScalars.count  // 2
tone.characters.count      // 2
```

---

^ Not even "characters" quite matches what you probably had in mind. And it gets crazier.

```swift
let family = "👨‍👨‍👦‍👦"
family.utf8.count            // 25 (!!!)
family.utf16.count           // 11
family.unicodeScalars.count  // 7
family.characters.count      // 4
```

^ The point is, how many elements are in a string is a very complicated question, and this is just French and emoji (though granted, emoji is really complicated). Add in some very specialized Arabic ligatures, vowel marks in several languages, combining accents, zero width characters, multi-directional text, and many other fascinating and infuriating features of human written expression, and questions like "what is character 4 in this string?" become rather... murky. And definitely not O(1).

^ So anyway, Strings aren't collections. They occasionally act like collections because they bridge to NSString, but don't be surprised when you need to use a specific view to get what you want.

---

^ Another interesting group of collections that can confuse you are Range and the Interval types.

### Ranges and Intervals

```swift
/// A collection of consecutive discrete index values.
struct Range<Element : ForwardIndexType>  { ... }

/// A half-open `IntervalType`, which contains its `start` but not its
/// `end`.  Can represent an empty interval.
struct HalfOpenInterval<Bound : Comparable> { ... }

/// A closed `IntervalType`, which contains both its `start` and its
/// `end`.  Cannot represent an empty interval.
struct ClosedInterval<Bound : Comparable> { ... }
```

^ Swift has both ranges and intervals, and it may not be immediately obvious why they're different.

---

### Range

```swift
/// A collection of consecutive discrete index values.
struct Range<Element : ForwardIndexType> { ... }

Range(start: 1, end: 6) // 1, 2, 3, 4, 5

1...6
```

^ Ranges are collections of indexes that include their start index, but not their end index, just like all collections.

---

### Intervals

```swift
/// A half-open `IntervalType`, which contains its `start` but not its
/// `end`.  Can represent an empty interval.
struct HalfOpenInterval<Bound : Comparable> { ... }

/// A closed `IntervalType`, which contains both its `start` and its
/// `end`.  Cannot represent an empty interval.
struct ClosedInterval<Bound : Comparable> { ...}

HalfOpenInterval(1.0, 6.0) // [1.0, 6.0)
1.0 ..< 6.0

ClosedInterval(1.0, 6.0)   // [1.0, 6.0]
1.0 ... 6.0

Range(start: 1.0, end: 6.0) // Error
```

^ Intervals are based on comparable types, not index types. Double is a comparable type for instance. In a general sense, there's no "next" double. Yes, there's some bit pattern for the next representable double, but abstractly, there's no "next" real number. They're not enumerable, so there's no successor() function, so you can't have a Range of them. But they are comparable, which means that you can tell if they're equal and if they're not equal, you can put them in order from lesser to greater, so you can use them for an Interval.

^ You can iterate over a Range. You can't iterate over an interval. On the other hand, given an arbitrary value, you can quickly tell if it's in an interval, but you may have to iterate over a range to determine if a value is within it.

---

### Closed Ranges?

^ OK, just one more thing. You remember that ranges don't include their end index. So how does a closed ... range work? Well, since there's a successor() function, Swift just calls it on the end you pass, and converts it into the half-open range like we need. You can't do that with an interval, since there's no successor, which is why you need separate half-open and closed interval types.

```swift
func ...<Pos : ForwardIndexType>(minimum: Pos, maximum: Pos) -> Range<Pos> {
    return Range(start: minimum, end: maximum.successor())
}

1...2 // ==> 1..<3
```

^ Neat, huh?

---

### Ranges in Swift 3

* Range
* ClosedRange
* CountableRange
* CountableClosedRange

^ Quick note on Swift 3. Ranges and Intervals are going to get a little more complicated, moving to four types, Range, ClosedRange, CountableRange, and CountableClosedRange. But eventually we hope we'll be able to get down to just Range and ClosedRange. Swift needs some new language features to make that possible, so we'll have to wait a little while.

---

## SetAlgebraType/OptionSetType

* Nice protocol for bit fields (particularly options)

```
struct PackagingOptions : OptionSetType {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let Box = PackagingOptions(rawValue: 1)
    static let Carton = PackagingOptions(rawValue: 2)
    static let Bag = PackagingOptions(rawValue: 4)
    static let Satchel = PackagingOptions(rawValue: 8)
    static let BoxOrBag: PackagingOptions = [Box, Bag]
    static let BoxOrCartonOrBag: PackagingOptions = [Box, Carton, Bag]
}

func shipit(packaging: PackagingOptions) {
    if packaging.contains(.Carton) {
        print("We need a Carton")
    }
}

shipit(.Box)
shipit(.BoxOrCartonOrBag)
shipit([.Box, .Carton])
```

^ This is one of those really cool types that I don't think people know enough about. It lets us manage bit-field style options in a really easy style. You can pass individual options or arrays, and then check for them using set operations like contains. I don't think I need to say a lot about this other than to remind you that it exists. The one thing to notice, that might not be obvious, is that this needs to be a struct, not an enum. It's more like a collection of values rather than one value from a list. If it were an enum, then every combination of values would have to be a case, and that would break the whole point.

---

## Zippers

^ I promised arrays to zippers, so let's talk about zippers before we wrap this up. What the heck is a zipper?

---

![fit](Zipper.pdf)

^ Say you have two sequences and want to work with them together as tuples.

---

```swift
let xs = [1, 2, 3, 4, 5]
let ys = ["A", "B", "C", "D", "E"]

for pair in zip(xs, ys) {
    print(pair)
}
==>
(1, A)
(2, B)
(3, C)
(4, D)
(5, E)
```

^ That's what zip does. It takes two sequences, and zips them together into a sequence of pairs. You might recognize this as the more general version of enumerate. If we wanted to, we could implement our own enumerate like this:

---

```swift
func myEnumerate<Seq: SequenceType>(base: Seq)
    -> AnySequence<(Int, Seq.Generator.Element)> {
        var n = 0
        let nats = AnyGenerator<Int> {
            defer { n += 1 }
            return n
        }
        return AnySequence(zip(nats, base))
}
```

^ This zips together an infinite sequence of integers, with the elements of the sequences. zip will stop as soon as one of the sequences runs out, so the output is as long as the base sequence.

---

```swift
func myEnumerate<Seq: SequenceType>(base: Seq)
    -> AnySequence<(Int, Seq.Generator.Element)> {
```

vs.

```swift
func myEnumerate<Seq: SequenceType>(base: Seq)
	-> Zip2<AnyGenerator<Int>, Seq>
```

^ Also see how I've used AnySequence here to type erase the output of zip. We just expose the tuples of ints and elements. Without using AnySequence, we'd have exposed our use of zip and AnyGenerator. So if we implemented this some other way, we'd have to modify our signature.

---

## And still there's more

* ManagedBuffer
* ImplicitlyUnwrappedOptional (going away in Swift 3)
* Mirror
* Repeat
* Process
* Optional
* RawByte
* Strides
* Unmanaged
* Unsafe
* VaListBuilder
* GeneratorSequence

^ I only had an hour for this talk, so I had to skip over some pieces. Some of these, like Optionals and the various Unsafe types I could probably give an entire talk on by themselves. Some, like Mirror, promise so much but are pretty limited today. But I suggest for all of you, spend some time just browsing through the Swift header file. It's got tons of comments, and you'll be surprised what you find in there.

---

^ So that's Arrays to Zippers. 

## Generator -> Sequence -> Collection

^ The most important thing I hope you take away from this is the basic approach Swift takes to the various collection types. Generators get you started. Sequences are super-basic and promise almost nothing. Collections are multi-pass, indexed sequences. And if you make your types conform to Sequence or Collection, you get a bunch of nice features for free.

---

# Array To Zipper

## [robnapier.net/cocoaconf](robnapier.net/cocoaconf)

