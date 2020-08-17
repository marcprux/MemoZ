# MemoZ – Zero-line Memoization for Swift

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20Linux-lightgrey.svg)](https://github.com/marcprux/MemoZ)

MemoZ is a cross-platform (Apple & Linux) microframework for [#zero-line] caching of computed properties:

```swift
import MemoZ
let value = SomeHashableValue()
let slow = value.expensiveComputation        // O(N)
let fast = value.memoz.expensiveComputation  // O(1)
```

## How does it work?

tl;dr: *Magic*

MemoZ provides an extension to `Hashable` with the property `memoz`, which will return a `Memoization` instance that dynamically passes-through the subsequent property accessor and caches the result in a global `NSCache`. It is designed to operate on value types (structs & enums), and requires that the computed property be a referentially transparent operation (dependent only on the subject value and no other external state).

## Sample Usage

The recommended convention for memoizing expensive computations in the property `prop` is to expose a memoized version of the property named `propZ`.

```swift
import MemoZ

extension Sequence where Element : Numeric {
    /// Computes the sum of all the elements.
    /// - Complexity: O(N)
    var sum: Element { self.reduce(0, +) }
}

extension Sequence where Element : Numeric, Self : Hashable {
    /// Computes & memoizes the sum of all the elements.
    /// - Complexity: Initial: O(N) MemoiZed: O(1)
    var sumZ: Element { self.memoz.sum }
}

// Measure the performance of non-memoized & memoized `sum`
class MemoZDemo: XCTestCase {
    /// A sequence of integers ranging from -1M through +1M
    let millions = (-1_000_000...1_000_000)

    func testCalculatedSum() {
        // average: 1.299, relative standard deviation: 0.509%, values: [1.312717, 1.296008, 1.306766, 1.298375, 1.299257, 1.303043, 1.296738, 1.294311, 1.288839, 1.293301]
        measure { XCTAssertEqual(millions.sum, 0) }
    }

    func testMemoizedSum() {
        // average: 0.133, relative standard deviation: 299.900%, values: [1.332549, 0.000051, 0.000018, 0.000032, 0.000110, 0.000021, 0.000016, 0.000015, 0.000014, 0.000123]
        measure { XCTAssertEqual(millions.sumZ, 0) }
    }
    
    override func tearDown() {
        super.tearDown()
        MemoizationCache.shared.clear() // clear out the global cache
    }
}
```


## Memoization

Wikipedia describes the technique of [memoization](https://en.wikipedia.org/wiki/Memoization) as:

> A memoized function "remembers" the results corresponding to some set of specific inputs. Subsequent calls with remembered inputs return the remembered result rather than recalculating it, thus eliminating the primary cost of a call with given parameters from all but the first call made to the function with those parameters. The set of remembered associations may be a fixed-size set controlled by a replacement algorithm or a fixed set, depending on the nature of the function and its use. A function can only be memoized if it is referentially transparent; that is, only if calling the function has exactly the same effect as replacing that function call with its return value. […]
> 
> Memoization is a way to lower a function's time cost in exchange for space cost; that is, memoized functions become optimized for speed in exchange for a higher use of computer memory space. The time/space "cost" of algorithms has a specific name in computing: computational complexity. All functions have a computational complexity in time (i.e. they take time to execute) and in space.


## Setup

MemoZ is distributed as a source-level Swift Package, 

### Swift Package Manager (SPM)

The Swift Package Manager is a dependency manager integrated with the Swift build system. To learn how to use the Swift Package Manager for your project, please read the [official documentation](https://github.com/apple/swift-package-manager/blob/master/Documentation/Usage.md).  
To add MemoZ as a dependency, you have to add it to the `dependencies` of your `Package.swift` file and refer to that dependency in your `target`.

```swift
// swift-tools-version:5.0
import PackageDescription
let package = Package(
    name: "<Your Product Name>",
    dependencies: [
        .package(url: "https://github.com/marcprux/MemoZ.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(name: "<Your Target Name>", dependencies: ["MemoZ"])
    ]
)
```

After adding the dependency, you can fetch the library with:

```bash
$ swift package resolve
```

### Xcode

You can add `MemoZ` to your Xcode Swift project with:

  1. `File` > `Swift packages` > `Add Package Dependency...`,
  2. Add the MemoZ repository: `https://github.com/marcprux/MemoZ`
  3. Use `1.0.0` (or `master` for bleeding-edge)
  4. Add `import MemoZ` to any source file that will use `memoz`

Alternatively, if you are trying to minimize dependencies, you can simply copy the `MemoZ.swift` file into your project: all the code is in that single small file, which itself has no dependencies of its own (other than Foundation).


## Error Handling

MemoZ uses the keyPath as a key for the memoization cache, and as such, are performed on computed properties (which can be implemented via extensions). Computed property accessors cannot throw errors, but error handling can be accomplished using the `Result` type. For example:

```swift
extension BidirectionalCollection {
    /// Returns the first and last element of this collection, or else an error if the collection is empty
    var firstAndLast: Result<(Element, Element), Error> {
        Result {
            guard let first = first else {
                throw CocoaError(.coderValueNotFound)
            }
            return (first, last ?? first)
        }
    }
}

/// `Result.get` is used to convert `Result.failure` into a thrown error
XCTAssertThrowsError(try emptyArray.memoz.firstAndLast.get())
```


## Memoizing Functions

Earlier versions of this library permitted the memoization of a function (either an anonymous inline closure or a named function) which was useful for those one-off calculation for which creating an extension on the subject type with a computed property might be overkill. 

The two problems with this approach were:

  1. Unlike a keypath, a function is not `Hashable` and so cannot participate in the cache key; this was worked around by keying on the calling source code file & line, but that was quite fragile.
  2. It is too easy to inadvertently capture local state in the function that contributed to the result value, but which wouldn't be included in the cache key, thereby leading the incorrect cache results being returned.

Forcing the calculation to be performed in a named property solves #1, and, while it isn't possible to enforce true purity in swift (e.g., nothing prevents your computed property from using `random()`), forcing the computation to be dependant solely on the state of the subject instance means that the subject will always itself be a valid cache key.


## Parameterizing Memoization

Although you cannot memoize an arbitrary function call, you can parameterize the computation by implementing the keyPath as a subscript with `Hashable` parameters. For example, if you want to be able to memoize the results of JSON encoding based on various formatting properties, you might make this extension on `Encodable`:

```swift
extension Encodable {
    /// A JSON blob with the given formatting parameters.
    subscript(JSONFormatted pretty: Bool, sorted sorted: Bool? = nil, noslash noslash: Bool = true) -> Result<Data, Error> {
        Result {
            let encoder = JSONEncoder()
            var fmt = JSONEncoder.OutputFormatting()
            if pretty { fmt.insert(.prettyPrinted) }
            if sorted ?? pretty { fmt.insert(.sortedKeys) }
            if noslash { fmt.insert(.withoutEscapingSlashes) }
            encoder.outputFormatting = fmt
            return try encoder.encode(self)
        }
    }
}
```

Since all of the parameter arguments to the keypath are themselves `Hashable`, you can memoize the results with:

```swift
try instance.memoz[JSONFormatted: true].get() // pretty
try instance.memoz[JSONFormatted: false, sorted: true].get() // unformatted & sorted
```

## Keying on KeyPath

The keyPath for memoizing can itself take a `keyPath` (since it is a `Hashable` parameter to the subscript), which allows memozied permutations on computations that work with key paths. For example:

```swift
extension Sequence {
    /// Sorts the sequence by the the given `keyPath` of the element
    subscript<T: Comparable>(sorting sortPath: KeyPath<Element, T>) -> [Element] {
        return self.sorted(by: {
            $0[keyPath: sortPath] < $1[keyPath: sortPath]
        })
    }
}

extension Array where Element: Collection & Hashable {
    /// "C", "BB", "AAA"
    var sortedByCountZ: [Element] {
        self.memoz[sorting: \.count]
    }
}

extension Array where Element: Comparable & Hashable {
    /// "AAA", "BB", "C"
    var sortedBySelfZ: [Element] {
        self.memoz[sorting: \.self]
    }
}

extension MemoZTests {
    func testMemoKeyedSubscript() {
        let strs = ["AAA", "C", "BB"]
        XCTAssertEqual(strs.sortedBySelfZ, ["AAA", "BB", "C"])
        XCTAssertEqual(strs.sortedByCountZ, ["C", "BB", "AAA"])
    }
}
```

## Inline Function Caching

You may want to memoize a function inline without having to make a calculating keyPath in a separate extension. This can be accomplished by wrapping the arguments to the function in a `Hashable` struct, and using an instance as the subject of  `memoz`:

```swift
/// Sum all the numbers from from to to
/// - Complexity: initial: O(to-from) memoized: O(1)
func summit(from: Int, to: Int) -> Int {
    /// Sum all the numbers from from to to
    /// - Complexity: O(to-from)
    func sumSequence(from: Int, to: Int) -> Int {
        (from...to).reduce(0, +)
    }

    /// Wrap the arguments to `sumSequence`
    struct Summer : Hashable {
        let from: Int
        let to: Int
        var sum: Int {
            sumSequence(from: from, to: to)
        }
    }

    return Summer(from: from, to: to).memoz.sum
}
```

This approach does introduce a lot of boilerplate to the memoization process, but an advantage is that the entire implementation can be encapsulated, and other types don't need to be "polluted" with computed properties that otherwise won't be used.

## Sequential Memoization

Note that the `memoz` only caches the adjacent keyPath. If you would like to memoize multiple sequential key paths, this can be done with multiple chained `memoz` calls, like so:

```swift
let costlyExpensiveSlowValue = instance.costlyProp.expensizeProp.slowProp
let fastQuickSpeedyValue = instance.memoz.costlyProp.memoz.expensizeProp.memoz.slowProp
```

## Thread Safety

MemoZ is as thread-safe as the underlying property computation. The cache is locked for reading and writing, but it should be noted that simultaneous executions of uncached property computations are **not** synchronized, which means that two computations can be performed simultaneously (one of whose results will be cached).

This example shows a `DispatchQueue` executing many memoizations in parallel:

```swift
extension MemoZDemo {
    /// A bunch of random numbers from the given offset
    func rangeLimts(count: Int = 20, offset: Int = 1_000_000) -> [Int] {
        (0..<count).map({ $0 + offset }).shuffled()
    }

    func testCalculatedSumParallel() {
        let ranges = rangeLimts()
        measure { // average: 7.115, relative standard deviation: 3.274%, values: [6.579956, 6.785192, 7.074619, 7.123436, 7.242951, 7.295850, 7.326060, 7.285277, 7.249500, 7.187203]
            DispatchQueue.concurrentPerform(iterations: ranges.count) { i in
                XCTAssertEqual((-ranges[i]...ranges[i]).sum, 0)
            }
        }
    }

    func testMemoziedSumParallel() {
        let ranges = rangeLimts()
        measure { // average: 0.671, relative standard deviation: 299.856%, values: [6.708572, 0.000535, 0.000298, 0.000287, 0.000380, 0.000400, 0.000337, 0.000251, 0.000225, 0.000183]
            DispatchQueue.concurrentPerform(iterations: ranges.count) { i in
                XCTAssertEqual((-ranges[i]...ranges[i]).sumZ, 0)
            }
        }
    }
}
```

## Cache Cleanup

`MemoZ` uses `NSCache`, which automatically drops values when memory pressure is experienced. The exact details of this process on macOS are vague, but you can also clear out the cache manually.

A common place to perform manual cache clearing in a mobile app is when the app enters the background: emptying the cache will reduce the app's overall memory footprint and thereby reduce the chances that the system will terminate the app (at the cost of needing to re-build the memoization cache if & when the app is again reactivated).

For an `AppDelegate`-based app, you can add:

```swift
func applicationDidEnterBackground(_ application: UIApplication) {
    MemoizationCache.shared.clear() // clear out the global cache
}
```

Or for SwiftUI:

```swift 
struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                MemoizationCache.shared.clear() // clear out the global cache
            }
        }
    }
}
```

## Cache Customization

Memoization caches can be partitioned into separate global caches, each with its own size limit:

```swift
extension MemoizationCache {
    /// A domain-specific cache that caps the number of cached instances at around 1,000
    static let domainCache = MemoizationCache(countLimit: 1_000)
}

func testCachePartition() {
    let uuids = (0...100_000).map({ _ in UUID() }) // a bunch of random strings
    measure {
        // the following two calls are the same, except the second one uses a custom cache rather than the default global cache
        XCTAssertEqual(3800038, uuids.memoz.description.count)
        XCTAssertEqual(3800038, uuids[memoz: .domainCache].description.count)
    }
}
```

The `countLimit` is an approximate maximum that the cache should hold. As per `NSCache`'s documentation:

> This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly, later, or possibly never, depending on the implementation details of the cache.

An additional advantage of using your own cache is that you can enable & disable it (by setting it to nil) on a global basis from a single location and compare the performance of your app with caching disabled.

## Measuring Performance 

Any caching solution, memoization included, introduces some performance overhead in time and space. As such, care should be taken that the memoized computation is actually costly enough to make caching worthwhile. 

For example, the following (pointless) memoization of a constant value would result in a **3x** performance degradation:

```swift
struct Pointless : Hashable {
    var alwaysOne: Int { 1 } // 1, always
    var alwaysOneZ: Int { memoz.alwaysOne } // we'd be better off without memoization!
}

func testPointlessComputation() {
    let pointless = Pointless()
    measure { // average: 0.013, relative standard deviation: 10.553%, values: [0.017202, 0.014706, 0.013114, 0.012666, 0.012782, 0.012689, 0.012770, 0.012431, 0.012440, 0.013157]
        for _ in 1...10_000 {
            XCTAssertEqual(1, pointless.alwaysOne)
        }
    }
}

func testPointlessMemoization() {
    let pointless = Pointless()
    measure { // average: 0.040, relative standard deviation: 3.971%, values: [0.043689, 0.039205, 0.038396, 0.041741, 0.038969, 0.039193, 0.039041, 0.039618, 0.038810, 0.038761]
        for _ in 1...10_000 {
            XCTAssertEqual(1, pointless.alwaysOneZ)
        }
    }
}
```

An advantage of `MemoZ`'s zero-line memoization is that you can easily put in measuring tests to ensure that memoization is actually worthwhile. A useful statistic is `XCTest`'s `measure` function, which runs the block 10 times and reports the individual times and the standard deviation between the times. A higher standard deviation generally indicates that the memoization is yielding a performance gain.

## Gotchas

Care must be taken that memozied computations are truly referentially transparent. It might be tempting to cache results of parsing dates or numbers using built-in static parsing utilities, but be mindful that these functions often take external environment settings (such as the current locale) into account, so if the environment changes between invocations, the memoized result will not be the same as the computed result.

In general, if your memoization subjects are **pure** value types (i.e., they transitively contain no properties that are reference)


## Implementation Details

MemoZ is a coarse-grained caching library that maintains a single global cache keyed by a combination of a target `Hashable` and a key path. As such, it *just works* for most cases, but care must be taken that:

 1. the target `Hashable` instance is a value type 
 2. the predicate keyPath is pure: is must have no side-effects and be referentially transparent

## “Zero-line”?

Many libraries advertise that their capabilities can be used in a single line of code. Since MemoZ's caching can be added to the same line of code as the property it is caching, it doesn't add **any** lines of code, and so it is a "zero-liner" instead of a "one-liner". 

Technically, one might say it is a “six-character” API (“`memoz.`” ), but “zero-line” sounds awesomer.

## Other Features

MicoMemo also exposes its own `Cache` instance that wraps an `NSCache` and permits caching value types (`NSCache` itself is limited to reference `AnyObject` instances for keys and values). 

The cache itself is not specific to memoization, so it can cache the results of an arbitrary function, at the cost of some additional book-keeping and cache key ceremony.

```swift
func testCacheAPI() {
    let cache = Cache<Int, String>()

    func cachedDescription(for number: Int) -> String {
        cache.fetch(key: number, create: { key in
            String(describing: key)
        })
    }

    XCTAssertEqual("123", cachedDescription(for: 123))
    XCTAssertEqual("123", cachedDescription(for: 123)) // this will return the cached result
    
    cache.clear()
    
    XCTAssertEqual("123", cachedDescription(for: 123)) // this will again be un-cached
}
```


## Testing

Tests on the host computer can be run with:

```console
swift test --enable-test-discovery
```

Container testing can be done with Docker. For examplem for Linux:

```console
docker run --rm --interactive --tty --volume "$(pwd):/src" --workdir "/src" swift:latest swift test --enable-test-discovery
```

