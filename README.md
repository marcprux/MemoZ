# Swift μmemo – micro-memoization

μmemo is a very simple memoization library that caches the the result of a pure function or calculated property for any Hashable value type. It uses `NSCache` to automatically purge memozied values.


## Setup
If you're running an Xcode project:

  1. select `File` -> `Swift packages` -> `Add Package Dependency...`,
  2. add this repo's git file `git@github.com:marcprux/MicroMemo.git` 
  3. use `master` or pin the appropriate version
  4. add `import MicroMemo`

## Sample usage:

For example:

```swift
import MicroMemo

extension Sequence where Element : Numeric {
    /// Add up the numbers
    var sum: Element { reduce(0, +) }
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
            XCTAssertEqual((-1_000_000...1_000_000).memoize(\.sum), 0)
        }
    }
}

```


## Details:

μmemo is a coarse-grained caching library that maintains a **single global cache** keyed by the **source code location** of calling code. As such, it *just works* for most cases, but care must be taken that:

 1. the target item is a `Hashable` value type 
 2. the predicate keyPath is pure
 3. the result of the function/property is a value type
