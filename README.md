# Swift μmemo – micro-memoization

MicroMemo provides an extension to `Hashable` with the property `memoz`, which will return a `Memoization` that will dynamically pass-through any subsequent keypath invocations and cache the result. So a call to `x.expensiveCalculation` can be memoized  simply by changing the call to `x.memoz.expensiveCalculation`.

## Sample usage:

```swift
import MicroMemo

extension Sequence where Element : Numeric {
    /// Add up the numbers
    var sum: Element { reduce(0, +) }

    /// Same as above, but also caches the result
    var summemo: Element { memoz.sum }
}

class MicroMemoDemo: XCTestCase {
    let millions = (-1_000_000...1_000_000)
    
    func testCalculatedSum() throws {
        // average: 1.325, relative standard deviation: 1.182%
        measure { XCTAssertEqual(millions.sum, 0) }
    }

    func testMemoizedSum() throws {
        // average: 0.130, relative standard deviation: 299.947% <- **10x speed gain**
        measure {  XCTAssertEqual(millions.summemo, 0) }
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
  2. add this repo's git file `git@github.com:marcprux/MicroMemo.git` 
  3. use `master` or pin the appropriate version
  4. add `import MicroMemo`

## Other Features:

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
        XCTAssertEqual(3800038, uuids.memoize(with: .domainCache, \.description).count)
    }
}
```

## Error Handling:

MicroMemo uses the keyPath as a key for the cache, and as such, need to be performed with calculated properties (typically implemented via extensions). Properties cannot throw errors, but error caching can be done using the `Result` type. For example:

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




## Implementation Details:

μmemo is a coarse-grained caching library that maintains a **single global cache** keyed by the key path. As such, it *just works* for most cases, but care must be taken that:

 1. the target item is a `Hashable` value type 
 2. the predicate keyPath is pure
 3. the result of the function/property is a value type
