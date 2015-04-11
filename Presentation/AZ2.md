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
## Stride
## Slice
## Generator

^ SequenceType. CollectionType. Those sound useful. Stride. Slice. Generator. I guess I've heard of those those before....

---

## ZipGenerator2
## MapSequenceGenerator
## BidirectionalReverseView
## LazyBidirectionalCollection

^ ZipGenerator2. MapSequenceGenerator? BidirectionalReverseView? LazyBidirectionalCollection. OK, this is getting a little silly.

---

## ExtendedGraphemeClusterLiteralConvertible

^ ExtendedGraphemeClusterLiteralConvertible. Now you're just messing with us.

^ Actually I am. We're not going to talk about that one. Today we're mostly going to talk about collections, well sequences. Well... mostly things you can generate and maybe a few other things. It'll make more sense as we go along.

---

Stdlib includes the obvious

```swift
/// Conceptually_, `Array` is an efficient, tail-growable random-access
/// collection of arbitrary elements.
struct Array { ... }
```

Alongside the obscure

```swift
/// Useful mainly when the optimizer's ability to specialize generics
/// outstrips its ability to specialize ordinary closures.
protocol Sink { ... }

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
protocol GeneratorType {
    typealias Element
    mutating func next() -> Element?
}
```

^ A generator can do just one thing: it can give you the next element if there is one. 

---

```swift
struct MyEmptyGenerator<Element>: GeneratorType {
    mutating func next() -> Element? {
        return nil
    }
}

var e = MyEmptyGenerator<Int>()
e.next() // => nil
e.next() // => nil
```

^ Let's build the simplest possible generator. The empty generator. Swift already provides this one, but let's build it ourselves.

^ That's as simple as they get. We just return nil and nil means we're done.

^ Notice that I declared `e` as `var`? That's on purpose and it's required. Generators encapsulate state, so they have to be mutable. 

> Generators are mutable so no else has to be.

---

```swift
struct MyGeneratorOfOne<T> : GeneratorType {
    var element: T?
    init(_ element: T?) { self.element = element }

    mutating func next() -> T? {
        let result = self.element
        self.element = nil
        return result
    }
}
```

^ OK, let's make it a little more interesting. Let's return exactly one element. Notice how I used `T` here rather than `Element` as my type, even though Swift requires a typealias called `Element`? Swift can work out through type-inference that `T` has to be the type required by the protocol. The stdlib likes to use `T` as "the parameterized type," so I'm using that style.

^ Now this isn't a bad implementation. It's probably very close to Apple's implementation. It at least behaves the same way. But it doesn't line up with Apple's recommendation.

---

Requires: `next()` has not been applied to a copy of `self`
since the copy was made, and no preceding call to `self.next()`
has returned `nil`.  Specific implementations of this protocol
are encouraged to respond to violations of this requirement by
calling `preconditionFailure("...")`.

^ So how would we do that? Well, we can keep track of whether we've returned nil before with an extra `done` property.

---

```swift
struct MyGeneratorOfOne<T> : GeneratorType {
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
```

^ I'm just throwing that out because Apple recommends it. I haven't found a single generator in stdlib that actually does this. They all just return nil repeatedly when they run out of elements. And keeping track of this case for the precondition call costs an extra property. So do what you want.

---

```swift
struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        return n++
    }
}

var nats = NaturalGenerator()
```

^ How about something that Swift doesn't give us? Let's build a generator of all the natural numbers starting at 0. We have some internal state, `n`, and we increment it every time `next()` is called. Note again how generators are inherently stateful and mutable. You're probably never going to encounter a `let` generator. That wouldn't really make sense.

^ Notice also that this generator never intentionally ends. It can keep creating values forever as long as you keep calling `next()`. Of course there's a limit on the size of `Int`, but this generate behaves like there isn't. It'll just overflow if you increment it too many times. There's nothing about a generator that says it has to be finite.

---

```swift
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
```

^ There's nothing about a generator that says it has to be deterministic or repeatable. This is a perfectly fine generator of a finite set of random numbers. A generator could pull packets from the network, or it elements from an array. Generators just generate values.

^ Questions?

---

## Generic Generators

^ Sometimes creating a whole new type for your generator is more trouble than it's worth. For a really simple generator, sometimes you'd rather just define it inline when you need it.

---

```swift
struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        return n++
    }
}
var nats = NaturalGenerator()
```

^ That Natural Number generator we created was really simple. All we really need is that `next()` function. It'd be nice if there were a generic generator that we could just pass that function to.

---

^ And of course there is. It's called `GeneratorOf`. With that, we could make our Natural generator this way. We just pass a closure and capture a local variable. We'll be seeing `GeneratorOf` several times today, so it's good understand what's happening here.

```swift
struct NaturalGenerator : GeneratorType {
    var n = 0
    mutating func next() -> Int? {
        return n++
    }
}
var nats = NaturalGenerator()
```

# :arrow_down:

```swift
var n = 0
var nats = GeneratorOf{ return n++ }
```

---

```swift
struct GeneratorOf<T> : GeneratorType, SequenceType {
    init(_ nextElement: () -> T?)
    init<G : GeneratorType where G.Element == T>(_ base: G)
...
}
```

^ We can construct a GeneratorOf two ways. We can either pass a `next()` function, or we can pass another generator. Passing another generator lets us hide the specific type we're using to generate values, and just expose "something that generates T."

---

```swift
func makeNaturalGenerator() -> GeneratorOf<Int> {
    var n = 0
    return GeneratorOf{ return n++ }
}

func makeNaturalGenerator() -> GeneratorOf<Int> {
    return GeneratorOf(NaturalGenerator())
}
```

^ So we can wrap up our natural generator as just a next() function, or we could type-erase our internal struct so we don't have to expose that.

---

## Sequences

^ Apple provides a number of useful generators that we'll discuss them more as we go along.

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
    typealias Generator : GeneratorType
    func generate() -> Generator
}
```

^ Here's the protocol. It needs some generator type and a way to create one. That's it. 

---

^ It may not be possible to iterate over a sequence more than once. This can surprise you sometimes. For example, consider this function.

## Danger ahead

```swift

func withoutMinMax<Seq: SequenceType 
	where Seq.Generator.Element : Comparable>
	(xs: Seq) -> [Seq.Generator.Element]{

	    let mn = minElement(xs)
	    let mx = maxElement(xs)

    	return filter(xs) { $0 != mn && $0 != mx }
}
```

^ Seems fine, but it's poorly defined behavior. It iterates over xs three times. There's no promise you can do that. If you want to be able to iterate more than once, you need to use a Collection, or as Apple sometimes says, "have static knowledge that the sequence is multipass."

---

```swift
struct MyEmptySequence<T> : SequenceType {
    func generate() -> EmptyGenerator<T> {
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
    func generate() -> GeneratorOf<Int> {
        var n = 0
        return GeneratorOf{ n++ }
    }
}
let nats = NaturalSequence()
```

^ Many of the sequences in stdlib have their own specialized generators, but you often can just use a generic generator and not create a new type. This is a really common use of GeneratorOf.

---

```swift
let nats = SequenceOf { () -> GeneratorOf<Int> in
    var n = 0
    return GeneratorOf { return n++ }
}
```

^ And like GeneratorOf, there's a generic Sequence called SequenceOf. It lets you wrap an arbitrary generate method as sequence. And like GeneratorOf, you can pass a sequence to SequenceOf to type-erase it.

---

### Impossible

```swift
// Drop some elements and return Seq
func drop<Seq: SequenceType>(n: Int, xs: Seq) -> Seq { ... }
```

^ Building reusable code around sequences can be useful, but there are a lot of limitations that can surprise you. I've already talked about how you can't assume sequences are multipass. You also can't assume that a sequence can be created. For example, say you wanted to create a sequence that dropped the first `n` elements. You'd probably think of something like this.

^ It's not possible to write that function. The SequenceType protocol doesn't define a way to create an empty sequence or extend a sequence or do any of the other things you'd need to do. If you think about it, it makes sense. Maybe your sequence has metadata attached to it. That might not be possible to create in general case.

---

### Possible

```swift
// Drop some elements and return SequenceOf
func myDrop<Seq: SequenceType>(n: Int, xs: Seq) 
	-> SequenceOf<Seq.Generator.Element> {
		var g = xs.generate()
		for _ in 1...n { g.next() }
		return SequenceOf{g}
}
```

^ There are several other versions we could create of course.

^ I don't know why this doesn't exist in stdlib. I've asked the Swift team, and so far haven't found anyone who knows, so maybe it's just an oversight.

^ `SequenceOf` takes an arbitrary sequence and returns another sequence that has the same kinds of elements. But it isn't the original type, so if that type had special features, they won't survive. And of course there's no promise that this function won't destroy the original sequence if it isn't multipass. That multipass thing just creeps in lot, and the type system doesn't help you with it. The caller just needs to know.

---

### Infinite sequences

```swift
func myCount<Seq: SequenceType>(xs: Seq) -> Int {
    return reduce(xs, 0) { (n, _) in n + 1 }
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
    for _ in xs { ++n }
    return n
}
```


^ And that's fine, too, but Swift doesn't provide this. Counting a sequence might consume the sequence, which is generally going to be unhelpful.

---

```swift
func underestimateCount<T : SequenceType>(x: T) -> Int
```

^ Instead, it provides `underestimateCount`, which promises not to consume any of your elements. If you pass it a collection, like an array, you'll get its length, but if you pass an unknown sequence type, it'll return 0. So that can be handy if you want to preallocate space when you can, but accept that sometimes you can't know how much.

---

## Collections

^ We've kind of talked this multipass problem to death now, but it has a big impact on stdlib. It means that often the preferred type is Collection, not Sequence, since a Collection is always multipass. So let's talk about Collection for a while.

^ If you've ever worked in a functional language, you probably are used to something like Sequence being the go-to type for building algorithms. But in Swift, the type you often need is Collection. Its just much more flexible than Sequence.

---

### Collections

* Conforms to SequenceType
* Multipass
* Efficient subscript using some index
* Iterates in subscript order

```swift
protocol CollectionType : SequenceType {
    typealias Index : ForwardIndexType

    var startIndex: Index { get }
    var endIndex: Index { get }

    subscript (position: Self.Index) -> Self.Generator.Element { get }
}
```

^ Let's look at the protocol. First-off, a collection is a multi-pass sequence. That's promised. And it has an index that you can use to efficiently fetch elements.

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

^ And those indexes should always be in the same order for a given instance. And collections also need to subscript on their index in O(1).

---

### Start with Sequence

```swift
struct MyEmptySequence<T> : SequenceType {
    func generate() -> EmptyGenerator<T> {
        return EmptyGenerator()
    }
}
```

^ Let's build some collections, and you'll see what I mean. We'll start with our EmptySequence and upgrade it to a collection.

---
### Upgrade to Collection

```swift
struct MyEmptyCollection<T> : CollectionType {
    func generate() -> EmptyGenerator<T> {
        return EmptyGenerator()
    }
}
```

---

### Index

```swift
struct MyEmptyCollection<T> : CollectionType {
    func generate() -> EmptyGenerator<T> {
        return EmptyGenerator()
    }
    typealias Index = Int    
}
```

^ We need to define an index type. Since this collection is empty, it doesn't really matter what the index type is, so we'll use something simple like `Int`.

---

### Start and end

```swift
struct MyEmptyCollection<T> : CollectionType {
    func generate() -> EmptyGenerator<T> {
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
struct MyEmptyCollection<T> : CollectionType {
    func generate() -> EmptyGenerator<T> {
        return EmptyGenerator()
    }
    typealias Index = Int
    let startIndex = 0
    let endIndex = 0    
    subscript (position: Index) -> T {
        fatalError("Out of bounds")
    }
}
```

^ And finally, there needs to be a way to subscript using your chosen index type. That's the minimum requirements to be a collection.

---

## Linked List

```swift
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

let l = List(1, List(2, List(3, .Nil)))
```

![right fit](Cons.pdf)


^ Let's make a little more interesting collection. How about a linked list?

^ Here's our basic structure. It's not a sequence or collection. It's just a simple list made up of Cons cells and Nil at the end. Cons is just an old Lisp term for an element and a "next" pointer. So we can build it up by passing a 1, followed by a list with a 2, followed list with a 3, followed by Nil. Like I say, this is a really common way to build a linked list.

^ There's a `Box` wrapper here to take of of the fact that Swift enums can't handle associated data with unknown sizes. It's not really important here; it's just needed by Swift.

---

## Some helpers

```swift
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
```

^ Just to simplify things, I'm going to assume we have some easy methods to get each part of the Cons cell.

---

```swift
extension List : SequenceType {
    func generate() -> GeneratorOf<T> {
        var node = self
        return GeneratorOf {
            let result = node.first()
            node = node.rest()
            return result
        }
    }
}
```

^ First, let's make this a Sequence so we can iterate over it. That means we just need to implement generate()

^ That's pretty straightforward. Start at the current node, and every time the next node is asked for, move forward.

---

### Index design

* Store iteration state: Cursor
* Efficient access

^ In order to make this a Collection, we need an index that we can use to save our state while iterating. I really want you to think about it that way. The Index isn't the way you fetch a value out of a collection. It's how you save your iteration state. It's a cursor.

^ What's that mean? It means that nine times out of ten, your Index isn't going to be an integer. We all look at Array, and it has this simple integer index, and we think oh! that's what an index is. But if you look through stdlib, you'll note that most collections use something other than Int as their index.

^ The key requirement is that subscripting by the index should be O(1). If you have the index, you should be able to jump right back to where you were when you fetched it. Computing the startIndex and endIndex should also be O(1).

---

### Types of Index

* `ForwardIndexType` :arrow_right: Can only move forward
* `BidirectionalIndexType` :arrow_right: Can move forward or backward
* `RandomAccessIndexType` :arrow_right: Can jump to any index

^ There are three kinds of indexes. Forward indexes can only move forward. Our linked list is like that. Given a location in the list, we can move forward easily, but we can't move backward. These are the simplest to implement. They just have a `successor` method.

^ A bidirectional index is like a doubly linked list. Given a location in the list, we can move forward or we can move backward. But there's no way to jump immediately to the third element. We have to start somewhere and move forward twice to get there. Strings have bidirectional indexes.

^ A random access index can jump to any element instantly without having to access other indexes first. The most common random access indexes are numbers. I can ask for the third element of an array without asking for the first and second. They're much more complicated than the other indexes, and most of the time they're just integers, though they can also be unsafe pointers.

^ Today we're just going to focus on the simplest form, the forward index.

---

^ Let's start with how we shouldn't do it. We shouldn't use an Int:

## Integer Subscripting
### Not a good List index

```swift
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
```

^ This is a really useful subscript. There's nothing wrong with this subscript. It's just not useful as an Index. This subscript is O(N). Collection algorithms may put index lookups in a loop, so that's O(N^2), which can really quickly become a problem. You'll also notice that this subscript returns an optional. You're free to do that in your subscripts. But the one you use for Collection has to return your element type. So that's no good.

---

### Indexes

* Need to remember the current iteration location
* Must be able to increment
* Must be able to compare for equality

^ What else could we use? Well, we want something that saves our place in our iteration, and can be used to move forward, and that we can test for equality.

^ The List itself handles the first two items easily. It include a pointer to our current position, and a pointer to our next position. The problem is equality checking. Saying that two lists are equal really means walking over the two lists and comparing their elements. That's too time consuming for an index equality check, which needs to be efficient.

^ There's a trick we could use by relying on the `Box` reference type and using `===` to find out if we have exactly the same objects. But that would get in the way of our implementing proper list equality later, so let's ignore that, and build a proper list index.

---

## A proper List index

```swift
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
```

^ Here's one way to do it. We keep track of the list, which is really our iteration state. And then we add an offset to give us something to compare for equality. Our rule is that if two offsets are equal, then the indexes are equal.

---

```swift
extension ListIndex : ForwardIndexType {
    func successor() -> ListIndex {
        let rest = self.node.rest()
        switch rest {
        case .Cons: 
        	return ListIndex(node: rest, index: self.index + 1)
        case .Nil:
        	 return .End
        }
    }
}

func == <T>(lhs: ListIndex<T>, rhs: ListIndex<T>) -> Bool {
    return lhs.index == rhs.index
}
```

^ So how do we implement ForwardIndexType? We need a successor and an equals. For successor, we look at the next element, and if it's not the end of the list, we return a new ListIndex with the next element, and we bump the offset by one to make it unique.

---

![fit](IterateList.pdf)

^ For equality, we just compare the offset values. Don't let that integer confuse you. It's not really the offset from the "start" of the list. There's no such thing, really. That's not how lists work. It's the offset from the start of an iteration over the list. So if I start iterating from element 1, then the offsets count up from there, starting at 0, and then go to -1 at the end. If I start iterating from element 2, then the offsets start counting up from there, starting at 0, and then go to -1 at the end. These integers are just internal implementation details to let us compare two indexes from the same iteration.

^ And since our indexes are only equatable, not comparable, offset -1 isn't "less than" offset 0. They're just not equal.

^ Make sense? Indexes are one of the more complicated pieces, so it's worth thinking about why this works.

---

## Now make it a Collection

```swift
extension List : CollectionType {
    typealias Index = ListIndex<T>
    var startIndex: Index { return .Start(self) }
    var endIndex: Index { return .End }

    subscript (i: Index) -> T {
        return i.node.first()!
    }
}
```

^ That's all we need. Now `ListIndex` is a valid `ForwardIndexType`. How do we fit it into our collection?

^ We need a startIndex. That's always the first cons cell, which is `self`, and an offset of 0.

^ We need an endIndex. That's the index one past the last element, and we use a consistent marker for that called .End with a node of .Nil and an offset of -1.

^ Notice that we don't need to know how far apart startIndex and endIndex are. You don't have to be able to do math on these values. It's ok that counting the elements is O(N), as long as you can jump to any place you've visited before in O(1).

^ And last we have the required subscript function. It just extracts the value at that index. And subscripting at the endIndex will crash. That's expected. endIndex is one *past* the end of the list.

---

^ Now that List is a Collection, we can make use of a convenience from the stdlib. Remember our generate method:

## Simplify `generate()`

```swift
extension List : SequenceType {
    func generate() -> GeneratorOf<T> {
        var node = self
        return GeneratorOf {
            let result = node.first()
            node = node.rest()
            return result
        }
    }
}
```

---

^ Rather than do this by hand, we can use `IndexingGenerator` to do the work for us:

## Simplify `generate()`

```swift
extension List : SequenceType {
    func generate() -> IndexingGenerator<List> {
        return IndexingGenerator(self)
    }
}
```

^ An IndexingGenerator can be the generator for any collection. It just uses your start, successor, and end, to access all the elements. For a type like List, this may not be the most efficient solution, since we have to allocate and destroy a bunch of ListIndex objects, but it definitely simplifies the code.

---

^ Now that we have a collection, we can use functions like find, first, isEmpty, and count. That's handy. But what about dropFirst?

## We get a bunch of helpers

`find`
`first`
`isEmpty`
`count`


## But can we `drop` yet?

```swift
func dropFirst<Seq : Sliceable>(s: Seq) -> Seq.SubSlice
```

-- Nope

^ Nope. We discussed this drop problem for sequences before, and how you might build it for sequences using SequenceOf. But the builtin dropFirst requires something more. It requires Sliceable.

---

## Sliceable

* Inherits from CollectionType
* A sub-range of elements can be efficiently extracted
* Slices should be temporary
* Type of SubSlice may be different from collection

^ A Sliceable is a Collection that you can extract a range from in O(1) time and memory.

^ That's really important because it means that a slice generally retains the whole underlying collection. If you have a million-entry list, and you slice out the first ten elements, the whole list stays around. A lot of weirdnesses about Sliceable come from that. Apple doesn't want you to unexpectedly hold onto large amounts of memory. So slices should be temporary. You usually don't want to store them in properties without converting them to a smaller collection.

---

## Unenforceable Sliceable Requirements

* SubSlice should be Sliceable
* SubSlice should have same element type as collection

^ The upside of all of this is that Sliceable probably the most tortured type in stdlib.

^ Sliceable requires this SubSlice type, which doesn't have to be the same type as the collection. SubSlice is supposed to be Sliceable itself, but Swift can't directly require that. Even worse, SubSlice's element type really needs to be the same as the element type of the collection, but Swift can't really express that either. All of this means that when you try to write generic functions against Sliceable, things often get a little messy.

---

## Slices in Swift

* String :arrow_right: String
* Array :arrow_right: ArraySlice

[https://devforums.apple.com/message/1105132](https://devforums.apple.com/message/1105132)
("Slice, Sliceable")

^ Swift only has two Sliceable collections: Array and String. String is its own SubSlice. Array has a separate ArraySlice. Both are views into the underlying collection, but Apple is more worried about people wasting memory by holding onto array slices than string slices, which is why arrays get their own special type.

^ If you want the gory details on this, along with Apple's thinking and all the rest, see this great thread in the dev forums. Search devforum for "Slice, Sliceable" and look for Dave Abrahams's posts.

---

```swift
struct ListSlice<T> {
    let list: List<T>
    let bounds: Range<List<T>.Index>
    func first() -> T? { return self.startIndex.node.first() }
    func rest() -> List<T> { return self.startIndex.node.rest() }
}
```

^ Anyway, let's build a slice for Lists. We'll build one that looks like ArraySlice.

^ We'll start with a simple data structure that takes a list and a range, and forwards some methods to the list.

---

^ So first, a Sliceable needs to be a Collection.

## Slices are Collections

```swift
extension ListSlice : CollectionType {
    typealias Index = List<T>.Index
    var startIndex: Index { return self.bounds.startIndex }
    var endIndex: Index { return self.bounds.endIndex }
    subscript (i: Index) -> T { return i.node.first()! }
    func generate() -> IndexingGenerator<ListSlice> {
        return IndexingGenerator(self)
    }
}
```

^ That's really simple. The start and end indexes are exactly what we were passed as bounds. And the subscript and generate methods are just like in List. Collections take a little planning, but the code often isn't really that hard.

---

^ And of course a slice should be sliceable.

## Slices are Sliceable

```swift
extension ListSlice : Sliceable {
    typealias SubSlice = ListSlice<T>
    subscript (bounds: Range<Index>) -> SubSlice {
        return ListSlice(list: self.list, bounds: bounds)
    }
}
```

^ We just need to implement a subscript that takes a range and returns a new ListSlice.

^ That's it. Now we can apply it to List, to make List Sliceable, too.

---

## And finally... a sliceable list

```swift
extension List : Sliceable {
    typealias SubSlice = ListSlice<T>
    subscript (bounds: Range<Index>) -> SubSlice {
        return ListSlice(list: self, bounds: bounds)
    }
}

dropFirst(myList).first() // Second element

```

^ It's almost identical to ListSlice. Now we can use dropFirst() on our list.

^ Questions?

---

^ Now that we've seen sequences and collections, we can go back and look at some more of the built-in generators that Swift provides.

## GeneratorSequence

^ In order to use the `for-in` syntax, you need a sequence.

```swift
for x in seq { ... }
```

^ But what if you just have a generator and want to iterate over it? It seems kind of silly to create a whole SequenceType just to wrap the a generator, and you don't have to. You can turn any generator into a sequence using GeneratorSequence, which is very similar to this SequenceOf call.

```swift
for x in GeneratorSequence(g) { ... }
```

```swift
for x in SequenceOf({g}) { ... }
```

^ You'll find that most of the built-in generators also happen to be sequences already to make this easier. For example, IndexingGenerator is also a SequenceType, so you don't need to wrap it again. 

---
<!-- 

## Building a Generator/Sequence

^ As long as we're here, let's look at how to build something like that.

```swift
struct RepeatForever<C: CollectionType> : SequenceType, GeneratorType {
    let baseCollection: C
    var baseGenerator: C.Generator?

    init (_ baseCollection: C) { self.baseCollection = baseCollection }

    mutating func next() -> C.Generator.Element? {
        if let result = self.baseGenerator?.next() {
            return result
        } else {
            self.baseGenerator = self.baseCollection.generate()
            return self.baseGenerator?.next()
        }
    }
    func generate() -> RepeatForever { return self }
}
```

^ RepeatForever is both a generator and a sequence. It creates a sub-generator on the collection and returns elements on that until it's empty, then it creates a fresh generator on the collection. As a sequence, it just returns itself as the generator.

---

^ Since this is both a sequence and a generator, you need to think a little bit about how it behaves if you call generate() after next() has been called:

## `generate` after `next`

```swift
var r = RepeatForever([1,2,3])
r.next() // ==> 1
var g = r.generate()
g.next() // ==> 2
```

^ That's correct behavior, in my opinion, and matches what SequenceGenerator does.

---

## Multi-pass
^ The next question is how this behaves if you call generate() multiple times.

```swift
let r = RepeatForever([1,2,3])
var g = r.generate()
g.next() // ==> 1
var h = r.generate()
h.next() // ==> 1

g.next() // ==> 2
g.next() // ==> 3

h.next() // ==> 2
```

^ Again, you'll notice that each generator is independent. Both of these facts are because RepeatForever is a value type, so when you return `self`, it's really an independent copy.

---
 -->

## PermutationGenerator

^ Since a Collection can be subscripted in any order, what if you chose your indexes according to some rule? You could use that to create all kinds of other sequences without having to copy your collection. The most basic permutation would return elements in the same order as the collection. Let's build that.

```swift
let xs = [3, 1, 4, 1, 5, 9, 2, 6, 5]
let orderedxs = PermutationGenerator(
    elements: xs,
    indices: indices(xs))
```

^ This creates a generator-sequence using the elements of xs and the indices of xs. 

---

^ Of course, since this is an Array, we can use a range of integers to get the same thing:

## PermutationGenerator

```swift
let xs = [3, 1, 4, 1, 5, 9, 2, 6, 5]
let orderedxs = PermutationGenerator(
    elements: xs,
    indices: 0..<xs.count)
```

---
^ Or we could get just the even elements:

## Just the evens

```swift
let evenxs = PermutationGenerator(
    elements: xs,
    indices: stride(from: 0, to: xs.count, by: 2))
```

---

^ Or reverse the sequence:

## Reverse

```swift
let reversexs = PermutationGenerator(
    elements: xs,
    indices: reverse(indices(xs)))
    
// let reversexs = reverse(xs)

```

^ Of course we could just reverse the collection directly with reverse, too.

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
* Append is O(1), prepend/insert is O(N)

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

---

### Local-mutation / Non-sharing

* Swift encourages local mutation
* Swift discourages shared mutable state (sort-of)

^ While Swift offers simple functional tools like map and filter, it doesn't have the rich assortment of functional tools you might find in other languges. Recursion isn't encouraged. This means that a for-in loop and calling `append` on a local `Array` is often the easiest and most natural way to do things. And it's the case that Swift tends to optimize.

^ On the other hand, Arrays are value types. That comes up all the time in the docs and on the forums. That means that when you pass arrays, you're passing copies. The fact that Swift spends so much effort to make copies pretty cheap drives home how important this value-type thing is. The core pieces of Swift encourage you to mutate locally, but not to share mutable things.

^ I say "sort-of" here because there are a lot of pieces of Swift that nudge you back towards reference types. Structs and enums have a lot of missing features that make them hard to rely on. And I think Swift definitely favors mutable data structures over persistent data structures like lenses or anything like that. There is a tendency towards immutability, but it's certainly not a core Swift philosophy.

---

### Local-mutation / Non-sharing (Performance)

```swift
// O(N)
func addOne(xs: [Int]) -> [Int] {
    return xs + [1]
}

// O(1)
func addOne(inout xs: [Int]) {
    xs.append(1)
}
```

^ And sometimes, even just value types introduce a major performance hit. Array copies are cheap as long as you don't modify them. Appending to an array means making a full copy.

---

```swift

// O(N^2)
func ones(n: Int) -> [Int] {
    if n == 0 { return [] }
    return [1] + ones(n - 1)
}

// O(N^2) (but currently faster)
reduce(1...n, [Int]()) { (a, _) in a + [1] }

// O(N)
func ones(n: Int) -> [Int] {
    var result: [Int] = []
    for _ in 1...n { result.append(1) }
    return result
}
```

^ This it often means recursion is really expensive. And `reduce` is a horrible way to build arrays. But here's the interesting point. Languages like Scala make this kind of elegant, recursive code really easy and discourage using loops or mutable variables. But if you look in the Scala standard library, lots of it is loops and mutable variables because it's more efficient.

---

> Swift tries to make efficient code more beautiful rather than beautiful code more efficient.
-- Rob's current gut feeling

^ So one way of looking at it is that Swift tries to make efficient code more beautiful rather than beautiful code more efficient. Swift makes it easier to write code that's going to run faster and use less memory, even if that means encouraging loops and local mutable variables.

---

^ Another key collection type is dictionary. Dictionaries are interesting because their index type isn't what it appears to be.  The index of Dictionary is DictionaryIndex, not the key. Dictionaries have two subscripts.

### Dictionaries

```swift
struct Dictionary<Key : Hashable, Value> : CollectionType {
	typealias Element = (Key, Value)
	typealias Index = DictionaryIndex<Key, Value>

	subscript(position: DictionaryIndex<Key, Value>) -> (Key, Value) { get }
	subscript(key: Key) -> Value?
}
```

^ The first takes its index. That's the subscript that allows dictionary to conform to CollectionType. You see how it returns the Element type, which it has to?

^ The key-based subscripting that returns an optional value has nothing to do with the CollectionType protocol. That's just a random subscript that Dictionary offers. Another good thing to study if you're thinking of creating your own collection types.

---

^ Strings are similar. You'd think you could index into strings by integer, but you can't. They use this special String.Index:

### Strings

```swift
extension String : CollectionType {
	struct Index : BidirectionalIndexType, Comparable, Reflectable {
		subscript (i: String.Index) -> Character { get }
	}
}
```

^ Converting strings into characters can be complicated, especially for UTF-8. Each character may be between one and four bytes long. So you can't jump an arbitrary character in a string without evaluating all the bytes before it. So the index is bidirectional, not random access. This is how you need to be thinking when you create your own collections. Of course you could write a subscript for String that takes an Int, but it'd be O(n), and that's not good for collections.

---

^ Another interesting group of collections that can confuse you are Range and the Interval types.

### Ranges and Intervals

```swift
/// A collection of consecutive discrete index values.
struct Range<T : ForwardIndexType> : Equatable, CollectionType {}

/// A half-open `IntervalType`, which contains its `start` but not its
/// `end`.  Can represent an empty interval.
struct HalfOpenInterval<T : Comparable> : IntervalType, Equatable {}

/// A closed `IntervalType`, which contains both its `start` and its
/// `end`.  Cannot represent an empty interval.
struct ClosedInterval<T : Comparable> : IntervalType, Equatable {}
```

^ Swift has both ranges and intervals, and it may not be immediately obvious why they're different.

---

### Range

```swift
/// A collection of consecutive discrete index values.
struct Range<T : ForwardIndexType> : Equatable, CollectionType {}
```

```swift
Range(start: 1, end: 6) // 1, 2, 3, 4, 5
```

^ Ranges are collections of indexes that include their start index, but not their end index, just like all collections.

---

### Intervals

```swift
/// A half-open `IntervalType`, which contains its `start` but not its
/// `end`.  Can represent an empty interval.
struct HalfOpenInterval<T : Comparable> : IntervalType, Equatable {}

/// A closed `IntervalType`, which contains both its `start` and its
/// `end`.  Cannot represent an empty interval.
struct ClosedInterval<T : Comparable> : IntervalType, Equatable {}
```

```swift
HalfOpenInterval(1.0, 6.0) // [1.0, 6.0)
ClosedInterval(1.0, 6.0)   // [1.0, 6.0]

Range(start: 1.0, end: 6.0) // Error
```

^ Intervals are based on comparable types, not index types. Double is a comparable type for instance. In a general sense, there's no "next" double. Yes, there's some bit pattern for the next representable double, but abstractly, there's no "next" real number. They're not enumerable, so there's no successor() function, so you can't have a Range of them. But they are comparable, which means that you can tell if they're equal and if they're not equal, you can put them in order from lesser to greater, so you can use them for an Interval.

^ You can iterate over a Range. You can't iterate over an interval. On the other hand, given an arbitrary value, you can quickly tell if it's in an interval, but you may have to iterate over a range to determine if a value is within it.

---

"Which function does Swift call?"
[http://airspeedvelocity.net/2014/09/20/which-func/](http://airspeedvelocity.net/2014/09/20/which-func/)

^ Swift tends to favor Ranges when given a choice. Airspeed Velocity has a six part series explaining exactly why and how. So I'm not going to go through all the details. This, by the way, is why Airspeed Velocity is my favorite Swift blog.

---

### Breaking Swift's brain

^ But I do want to touch on one point that has burned me.

```swift
let ranges = [
    1...2,
    1...2,
    1...2,
    1...2,
    1...2,
    1...2,
    1...2,
    1...2,
    1...2,
    1...2,
]
```

^ Currently this will break Swift's brain. I mean, it'll compile, but it takes forever. The reason is that the ... operator can return either ranges or intervals, and Swift will go crazy trying to decide which one it should be. At least I think that's the problem. The solution is just to tell Swift which one you want:

---

### Giving Swift a break

```swift
let ranges = [
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
    Range(start: 1, end: 2),
]
```

^ Then it's fine. I'm sure the compiler will eventually handle this, but it burned me.

---

### Closed Ranges?

^ OK, just one more thing. You remember that ranges don't include their end index. So how does a closed ... range work? Well, since there's a successor() function, Swift just calls it on the end you pass, and converts it into the half-open range like we need. You can't do that with an interval, since there's no successor, which is why you need separate half-open and closed interval types.

```swift
func ...<Pos : ForwardIndexType>(minimum: Pos, maximum: Pos) -> Range<Pos> {
    return Range(start: minimum, end: maximum.successor())
}
```

```swift
1...2 // ==> 1..<3
```

^ Neat, huh?

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
    println(pair)
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
func myEnumerate<Seq : SequenceType>(base: Seq)
    -> SequenceOf<(Int, Seq.Generator.Element)> {
    
        var n = 0
        let nats = GeneratorOf { n++ }
        return SequenceOf(zip(nats, base))
}
```

^ This zips together an infinite sequence of integers, with the elements of the sequences. zip will stop as soon as one of the sequences runs out, so the output is as long as the base sequence.

---

```swift
func myEnumerate<Seq : SequenceType>(base: Seq)
    -> SequenceOf<(Int, Seq.Generator.Element)>
```

vs.

```swift
func myEnumerate<Seq : SequenceType>(base: Seq)
	-> Zip2<GeneratorOf<Int>, Seq>
```

^ Also see how I've used SequenceOf here to type erase the output of zip. We just expose the tuples of ints and elements. Without using SequenceOf, we'd have exposed our use of zip and GeneratorOf. So if we implemented this some other way, we'd have to modify our signature.

^ That said, nothing in stdlib returns SequenceOf, and Apple says it's often due to optimization concerns. Some of that is just the immaturity of the compiler. And because Apple is writing code everyone relies on. But the advice from Apple is that returning SequenceOf is good Swift style, and there's no need to generate your own special sequence types in most cases.

---

^ So that's Arrays to Zippers. 

## Generator -> Sequence -> Collection -> Sliceable

^ The most important thing I hope you take away from this is the basic approach Swift takes to the various collection types. Generators get you started. Sequences are super-basic and promise almost nothing. Collections are multi-pass, indexed sequences. Sliceables are Collections that you can slice a temporary view from without copying.

---

# Array To Zipper

## [robnapier.net/cocoaconf](robnapier.net/cocoaconf)

---

# Just One More Thing...

---

## Laziness

---

## Mapping every element

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
	println(x)
}
```

---

^ Creating a huge temporary array of transformed values here would be a huge waste of time and memory. Of course we could just write it like this:

## Mapping too soon (fix)

```swift
for x in xs {
	println(f(x))
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

^ So what can we do about it? We can use laziness.

## Map/filter chains (fix)

```swift
let smalldoublexs = lazy(xs)
    .map { $0 * 2 }
    .filter { $0 < 10 }.array
```

^ Each element is completely processed before being put into the final result. Calling `array` at the end makes sure everything is calculated and we're left with an array rather than a lazy sequence. We can think of strict versus lazy as horizontal versus vertical.

---

^ But laziness can be even more powerful if we don't need all the results. For example:

## No unasked multiplies

```swift
let xs = [3, 1, 4, 1, 5, 9, 2, 6, 5]
let doublexs = lazy(xs)
	.map { $0 * 2 }
let doubleSecond = doublexs[1]
```

^ Without laziness, this computes all 16 doubles. With laziness, it computes just one. Notice we didn't call array here; that's important.

^ So if laziness is so great, why isn't it the default?

^ Well, in the first betas of Swift, it was the default. Mapping and filtering arrays returned lazy sequences rather than new arrays. But laziness isn't always what you want. Lazy sequences don't cache, or memoize. That means that every time you access an element, it has to recalculate it. Why doesn't Swift memoize the elements? Well, if you only access them once, then that would defeat the point of being lazy, since you'd have to allocate all the memory for the memozied values.

^ Laziness can also surprise you about *when* the calculation happens. With lazy sequences, the processing happens when you access the value. So say you downloaded a bunch of JSON on a background thread, and parsed it down to some kind of data structures an passed that to the main thread. If that is done lazily, then the actual parsing will happen on the main thread when you access the data, which is probably the opposite of what you wanted. Rather than surprise you, Swift now is strict by default, and you have to ask for laziness when you want it.

^ So, that's what laziness is all about. How do you actually use it in Swift? The vast majority of the time, you just wrap the thing you want to be lazy in a call to lazy(). So what does that do?

---

## The many faces of `lazy`

```swift
/// Augment `s` with lazy methods such as `map`, `filter`, etc.
func lazy<S : CollectionType where S.Index : ForwardIndexType>(s: S) 
	-> LazyForwardCollection<S>

/// Augment `s` with lazy methods such as `map`, `filter`, etc.
func lazy<S : SequenceType>(s: S) 
	-> LazySequence<S>

/// Augment `s` with lazy methods such as `map`, `filter`, etc.
func lazy<S : CollectionType where S.Index : RandomAccessIndexType>(s: S) 
	-> LazyRandomAccessCollection<S>

/// Augment `s` with lazy methods such as `map`, `filter`, etc.
func lazy<S : CollectionType where S.Index : BidirectionalIndexType>(s: S) 
	-> LazyBidirectionalCollection<S>
```

^ It just wraps what you hand it in a wrapper that adds lazy versions of map and filter.

^ You see how we can have sequences, forward collections, bidirectional collections, and random access collections. That should be pretty clear. A singly linked list is a collection that only goes forward. A doubly linked list goes both ways. And an array can pick any element by number.

---

```swift
extension LazySequence {
    func filter(includeElement: (S.Generator.Element) -> Bool)
    	-> LazySequence<FilterSequenceView<S>>
    func map<U>(transform: (S.Generator.Element) -> U)
    	-> LazySequence<MapSequenceView<S, U>>
}
```

^ You see there that the LazySequence wraps a SequenceView. A "view" in Swift tranforms something without making a copy. You can't construct FilterSequenceView or MapSequenceView directly. Their inits are private. So they're really just an implementation detail of the lazy data strutures.

---

^ Let's look at how collections work with laziness:

```swift
extension LazyRandomAccessCollection {
    func filter(includeElement: (S.Generator.Element) -> Bool)
    	-> LazySequence<FilterSequenceView<S>>
	func map<U>(transform: (S.Generator.Element) -> U)
		-> LazyRandomAccessCollection<MapCollectionView<S, U>>
}
```

^ Notice how mapping returns a new collection, but filtering returns a sequences. If you filter lazily, you don't know how many elements there are going to be until you calculate them. With a little more work, I think Swift could return a LazyForwardCollection here rather than LazySequence, but it doesn't, and usually that doesn't really matter.

---

^ One more little trick before we move on. Even if you don't need laziness, sometimes the lazy() function is really handy anyway. SequenceType and CollectionType don't have map and filter methods. Say you wanted every other element of an array. You could use `enumerate` to get that:

```
let everyother = enumerate(xs)
    .filter { (i, v) in i % 2 == 0 }
    .map    { (_, v) in v } // ERROR
```

^ enumerate() creates a series of pairs of indexes and values. You then filter by even indexes, and then map back to the values. This would take something like three times the memory of the array, but if it's short, maybe you don't care. But this won't compile. Enumerate returns a Sequence, and there's no filter method on Sequence. Someday I expect there will be, but not today. So how do you fix that? Lazy to the rescue:

---

```
let everyother = lazy(enumerate(xs))
    .filter { (i, v) in i % 2 == 0 }
    .map    { (_, v) in v }.array
```

^ Lazy converts the sequence into a lazy sequence. And *that* has a filter method on it.

---

* Laziness is opt-in
* Good for map/filter chains
* Nice for getting methods onto generic sequences
* Allows map/filter on infinite sequences
