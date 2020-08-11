# MicroMemo

A simple memoization library that can memoize the the result of a pure function or calculated property on any Hashable instance.

For example:

```swift
/// Import MicroMemo with:
/// Xcode > File > Swift Packages > Add Package Dependency…
/// https://github.com/marcprux/MicroMemo.git
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


