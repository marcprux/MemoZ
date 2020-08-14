# Swift μmemo – micro-memoization

μmemo is a very simple memoization library that caches the the result of a pure function or calculated property for any Hashable value type. It uses `NSCache` to automatically purge memozied values.


## Setup
If you're running an Xcode project:

  1. select `File` -> `Swift packages` -> `Add Package Dependency...`,
  2. add this repo's git file `git@github.com:marcprux/MicroMemo.git` 
  3. use `master` or pin the appropriate version
  4. add `import MicroMemo`

## Sample usage:

MicroMemo provides an extension to `Hashable` with the property **`mmz`**, which will return a `Memoization` that will dynamically pass-through any subsequent keypath invocations and cache the result. So a call to `x.expensiveCalculation` can be memoized  simply by changing the call to `x.mmz.expensiveCalculation`.

For example:

```swift
import MicroMemo

extension Sequence where Element : Numeric {
    /// Add up the numbers
    var sum: Element { reduce(0, +) }

    /// Same as above, but additionally caches the result
    var memosum: Element { mmz.sum }
}

class MicroMemoDemo: XCTestCase {
    /// Test that the sum of -1M through +1M is zero. Unmemozied.
    func testCalculatedSum() throws {
        measure { // average: 1.325, relative standard deviation: 1.182%
            XCTAssertEqual((-1_000_000...1_000_000).sum, 0)
        }
    }

    /// Test that the sum of -1M through +1M is zero. Memozied for a 10x win!
    func testMemoizedSum() throws {
        measure { // average: 0.130, relative standard deviation: 299.947%
            XCTAssertEqual((-1_000_000...1_000_000).mmz.sum, 0)
        }
    }
}

```

## Memoization

Wikipedia describes the technique of [memoization](https://en.wikipedia.org/wiki/Memoization) as:

> A memoized function "remembers" the results corresponding to some set of specific inputs. Subsequent calls with remembered inputs return the remembered result rather than recalculating it, thus eliminating the primary cost of a call with given parameters from all but the first call made to the function with those parameters. The set of remembered associations may be a fixed-size set controlled by a replacement algorithm or a fixed set, depending on the nature of the function and its use. A function can only be memoized if it is referentially transparent; that is, only if calling the function has exactly the same effect as replacing that function call with its return value. (Special case exceptions to this restriction exist, however.) While related to lookup tables, since memoization often uses such tables in its implementation, memoization populates its cache of results transparently on the fly, as needed, rather than in advance.
> 
> Memoization is a way to lower a function's time cost in exchange for space cost; that is, memoized functions become optimized for speed in exchange for a higher use of computer memory space. The time/space "cost" of algorithms has a specific name in computing: computational complexity. All functions have a computational complexity in time (i.e. they take time to execute) and in space.



## Implementation Details:

μmemo is a coarse-grained caching library that maintains a **single global cache** keyed by the key path. As such, it *just works* for most cases, but care must be taken that:

 1. the target item is a `Hashable` value type 
 2. the predicate keyPath is pure
 3. the result of the function/property is a value type
