# MemoZ – Zero-line Memoization for Swift

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20Linux-lightgrey.svg)](https://github.com/marcprux/MemoZ)

MemoZ provides zero-line caching for Swift properties:

```swift
let slow: X = x.costly        // O(N)
let fast: X = x.memoz.costly  // O(1)
```

## How does it work?

MemoZ provides an extension to `Hashable` with the property `memoz`, which will return a `Memoization` instance that dynamically passes-through the subsequent property accessor and caches the result in a global `NSCache`.

## Sample usage

```swift
import MemoZ

extension Sequence where Element : Numeric {
    /// Adds up all the numbers
    var sum: Element { reduce(0, +) }
}

class MemoZDemo: XCTestCase {
    let millions = (-1_000_000...1_000_000)
    
    func testCalculatedSum() throws {
        // average: 1.325, relative standard deviation: 1.182%
        measure { XCTAssertEqual(millions.sum, 0) }
    }

    func testMemoizedSum() throws {
        // average: 0.130, relative standard deviation: 299.947% <- **10x speed gain**
        measure { XCTAssertEqual(millions.memoz.sum, 0) }
    }
}

```


## Memoization

Wikipedia describes the technique of [memoization](https://en.wikipedia.org/wiki/Memoization) as:

> A memoized function "remembers" the results corresponding to some set of specific inputs. Subsequent calls with remembered inputs return the remembered result rather than recalculating it, thus eliminating the primary cost of a call with given parameters from all but the first call made to the function with those parameters. The set of remembered associations may be a fixed-size set controlled by a replacement algorithm or a fixed set, depending on the nature of the function and its use. A function can only be memoized if it is referentially transparent; that is, only if calling the function has exactly the same effect as replacing that function call with its return value. (Special case exceptions to this restriction exist, however.) While related to lookup tables, since memoization often uses such tables in its implementation, memoization populates its cache of results transparently on the fly, as needed, rather than in advance.
> 
> Memoization is a way to lower a function's time cost in exchange for space cost; that is, memoized functions become optimized for speed in exchange for a higher use of computer memory space. The time/space "cost" of algorithms has a specific name in computing: computational complexity. All functions have a computational complexity in time (i.e. they take time to execute) and in space.


## Setup

MemoZ is distributed as a source-level Swift Package, which can be added to your Xcode project with:

  1. `File` > `Swift packages` > `Add Package Dependency...`,
  2. Add the MemoZ repository: `https://github.com/marcprux/MemoZ`
  3. Use `master` or pin the appropriate version
  4. Add `import MemoZ` to any source file that will use `memoz`

Alternatively, if you are trying to minimize dependencies, you can simply copy the `MemoZ.swift` file into your project: all the code is in that single small file, which itself has no dependencies of its own (other than Foundation).


## Error Handling

MemoZ uses the keyPath as a key for the memoization cache, and as such, need to be performed with calculated properties (which can be implemented via extensions). Property accessors cannot throw errors, but error handling can be accomplished using the `Result` type. For example:

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

Earlier versions of this library permitted the memoization of a function (either an anonymous inline closure or a named function) which was useful for those one-off calculation for which creating an extension on the subject type with a calculated property might be overkill. 

The two problems with this approach were:

  1. Unlike a keypath, a function is not `Hashable` and so cannot participate in the cache key; this was worked around by keying on the calling source code file & line, but that was quite fragile.
  2. It is too easy to inadvertently capture local state in the function that contributed to the result value, but which wouldn't be included in the cache key, this leading the incorrect cache results being returned.

Forcing the calculation to be performed in a named property solves #1, and, while it isn't possible to enforce true purity in swift (e.g., nothing prevents your calculated property from using `random()`), forcing the calculation to be dependant solely on the state of the subject instance means that the subject will always itself be a valid cache key.


## Parameterizing Memoization

Although you cannot memoize an arbitrary function call, you can parameterize the memoization calculation by implementing the keyPath as a subscript with `Hashable` parameters. For example, if you want to be able to memoize the results of JSON encoding based on various formatting properties, you might make this extension on `Encodable`:

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

This approach does introduce a lot of boilerplate to the memoization process, but an advantage is that the entire implementation can be encapsulated, and other types don't need to be "polluted" with calculated properties that otherwise won't be used.

## Sequential Memoization

Note that the `memoz` only caches the adjacent keyPath. If you would like to memoize multiple sequential key paths, this can be done with multiple chained `memoz` calls, like so:

```swift
instance.memoz.costlyProp.memoz.expensizeProp.memoz.slowProp…
```

## Thread Safety

MemoZ is safe to use from multiple threads but its caching accessors do not lock on access, which means that multiple threads simultaneously trying to memoize the same key path may wind up invoking the same calculation twice. It should always be assumed that any calculation performed in the target's keyPath might be run simultaneously on multiple threads, either when the cache is initially loaded, or subsequently due to re-evaluation after a cache eviction.


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


## Gotchas

Care must be taken that the calculation is truly referentially transparent. It might be tempting to cache results of parsing dates or numbers using built-in static parsing utilities, but be mindful that these functions typically take the current locale into account, so if the locale changes between invocations, the difference may not be seen when results are returned from the memoization cache.


## Implementation Details

MemoZ is a coarse-grained caching library that maintains a single global cache keyed by a combination of a target `Hashable` and a key path. As such, it *just works* for most cases, but care must be taken that:

 1. the target `Hashable` instance is a value type 
 2. the predicate keyPath is pure: is must have no side-effects and be referentially transparent


## Other Features

MicoMemo also exposes its own `Cache` instance that wraps an `NSCache` and permits caching value types (`NSCache` itself is limited to reference types for keys and values). 

## Testing

Tests on the host computer can be run with:

```console
swift test --enable-test-discovery
```

Container testing can be done with Docker. For examplem for Linux:

```console
docker run --rm --interactive --tty --volume "$(pwd):/src" --workdir "/src" swift:latest swift test --enable-test-discovery
```

