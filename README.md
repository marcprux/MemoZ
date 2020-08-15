# MemoZ – memoize referentially transparent properties in Swift

MemoZ provides an extension to `Hashable` with the property `memoz`, which will return a `Memoization` that will dynamically pass-through any subsequent keypath invocations and cache the result. So an expensive call to:

`x.expensiveCalculation`

can be memoized simply by interleaving the `memoz`:

`x.memoz.expensiveCalculation`

and the `expensiveCalculation` will be cached the first time it is called, and subsequent calls will return the cached value (until the cache is purged).

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
If you're running an Xcode project:

  1. select `File` -> `Swift packages` -> `Add Package Dependency...`,
  2. add this repo's git file `git@github.com:marcprux/MemoZ.git` 
  3. use `master` or pin the appropriate version
  4. add `import MemoZ`


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

## Sequential Memoization

Note that the `memoz` only caches the adjacent keyPath. If you would like to memoize multiple sequential key paths, this can be done with multiple chained `memoz` calls, like so:

```swift
instance.memoz.costlyProp.memoz.expensizeProp.memoz.slowProp…
```

## Gotchas

Care must be taken that the calculation is truly referentially transparent. It might be tempting to cache results of parsing dates or numbers using built-in static parsing utilities, but be mindful that these functions typically take the current locale into account, so if the locale changes between invocations, the difference may not be seen when results are returned from the memoization cache.


## Implementation Details

MemoZ is a coarse-grained caching library that maintains a single global cache keyed by a combination of a target `Hashable` and a key path. As such, it *just works* for most cases, but care must be taken that:

 1. the target `Hashable` instance is a value type 
 2. the predicate keyPath is pure: is must have no side-effects and be referentially transparent


## Thread Safety

MemoZ's caching is thread-safe, mostly through `NSCache`'s own thread-safe accessors. It should be noted that while `MicoMemo.Cache` has an option for forcing exclusive cache access (e.g., so mutiple simultaneous initial cache accesses for an instance will line up and wait for a single cache calculation to be performed), `memoz` does *not* enforce exclusivity. 

It should always be assumed that any calculation performed in the target's keyPath might be run simultaneously on multiple threads, either when the cache is initially loaded, or subsequently due to re-evaluation after a cache eviction.


## Other Features

MicoMemo also provides a `Cache` instance that wraps an `NSCache` and permits caching value types (`NSCache` itself is limited to reference types for keys and values). Memoization caches can be partitioned into separate global caches like so:

```swift
extension MemoizationCache {
    /// A domain-specific cache
    static let domainCache = MemoizationCache()
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

An advantage of using your own cache is that you can enable & disable it (by setting it to nil) on a global basis from a single location and compare the performance of your app with caching disabled.


