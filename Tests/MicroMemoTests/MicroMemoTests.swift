
import XCTest
import MicroMemo

extension Sequence where Element : Numeric {
    var sum: Element { reduce(0, +) }
    var product: Element { reduce(1, *) }
}

extension BinaryInteger where Self.Stride : SignedInteger {
    var isEven: Bool { self % 2 == 0 }
    var squareRoot: Double { sqrt(Double(self)) }
    func isMultiple(of i: Self) -> Bool { self % i == 0 }

    var isPrime: Bool {
        self <= 1 ? false : self == 2 ? true
            : (3...Self(self.squareRoot)).first(where: isMultiple(of:)) == .none
    }
}

final class SummingTests: XCTestCase {
    func testSum() {
        XCTAssertEqual(15, (1...5).sum)
        XCTAssertEqual(15, (1...5).memoz.sum)
        XCTAssertEqual(120, (1...5).product)
        XCTAssertEqual(120, (1...5).memoz.product)
        XCTAssertEqual(true, 87178291199.isPrime)

        XCTAssertEqual(false, UInt64(3314192745739 - 1).isPrime)
        XCTAssertEqual(true, UInt64(3314192745739).isPrime)
        XCTAssertEqual(false, UInt64(3314192745739 + 1).isPrime)

        //XCTAssertEqual(true, UInt64(3331113965338635107).isPrime) // 1,133 seconds!
        XCTAssertEqual(false, 1002.isPrime)

        XCTAssertEqual(false, 1002.memoz.isPrime)

    }

    func testValueTypes() {
        let str = "xyz" as NSString
        XCTAssertEqual(3, (str as String).memoz.count)
        XCTAssertEqual("Xyz", (str as NSString).memoz.capitalized) // we should get a deprecation warning here
    }

    func testCachePartition() {
        let uuids = (0...100_000).map({ _ in UUID() })
        measure {
            // the following two calls are the same, except the second one uses a partitioned cache
            XCTAssertEqual(3800038, uuids.memoz.description.count)
            XCTAssertEqual(3800038, uuids.memoize(with: .domainCache, \.description).count)
        }
    }

    func testErrorHandling() {
        XCTAssertThrowsError(try Array<Bool>().memoz.firstAndLast.get())
    }

}

extension MemoizationCache {
    /// A domain-specific cache
    static let domainCache = MemoizationCache()
}

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
