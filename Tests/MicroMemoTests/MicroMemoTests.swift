
import XCTest

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
        XCTAssertEqual(15, (1...5).memoize(\.sum))
        XCTAssertEqual(120, (1...5).product)
        XCTAssertEqual(120, (1...5).memoize(\.product))
        XCTAssertEqual(true, 87178291199.isPrime)

        XCTAssertEqual(false, UInt64(3314192745739 - 1).isPrime)
        XCTAssertEqual(true, UInt64(3314192745739).isPrime)
        XCTAssertEqual(false, UInt64(3314192745739 + 1).isPrime)

        //XCTAssertEqual(true, UInt64(3331113965338635107).isPrime) // 1,133 seconds!
        XCTAssertEqual(false, 1002.isPrime)
    }
}























@testable import MicroMemo

//final class MicroMemoTests: XCTestCase {
//    func testMemoize() throws {
//        func fibN(_ num: Int) -> Int { return num > 1 ? fibN(num - 1) + fibN(num - 2) : num }
//
//        // we expect to get a deprecation warning: "'memoize(sourceIdentifier:sourceIndex:_:)' is deprecated: memoize should not be used with reference types"
//        // XCTAssertEqual(497105937, NSString("ABC").memoize(\.hash))
//
//        // this should side-step the error since it is calling the hashable's
//        XCTAssertEqual(497105937, NSString("ABC").memoize(with: .shared, \.hash))
//
//        let list = ["A", "B", "C"]
//
//        XCTAssertNotEqual(list.memoize(\.first),
//                          list.memoize(\.last))
//
//        // fundamental memoize problem: two separate cache calls on the same line will use the same cache!
//        XCTAssertEqual(list.memoize(\.first), list.memoize(\.last))
//
//        let list2 = ["A", "B", "C"] // even though this is a different instance, it will still match the cache key
//        XCTAssertEqual(list.memoize(\.first), list2.memoize(\.last))
//
//        let list3 = ["X", "Y", "Z"] // but an acutally different instance will not trigger this issue
//        XCTAssertNotEqual(list.memoize(\.first), list3.memoize(\.last))
//
//        struct Fibber : Hashable {
//            var num: Int
//
//            /// Returns the Fibonacci number at the `num` index
//            var fib: Int {
//                // fibUncached // measured [Time, seconds] average: 0.352
//                fibCached // measured [Time, seconds] average: 0.036
//            }
//
//            /// An expensive fib calculation
//            private var fibUncached: Int { fibN(num) }
//
//            /// A cached fib calculation
//            private var fibCached: Int { memoize(\.fibUncached) }
//
//        }
//
//        MemoizationCache.shared.clear() // start fresh
//
//        measure {
//            var fibber = Fibber(num: 8)
//            XCTAssertEqual(21, fibber.fib)
//            fibber.num = 14
//            XCTAssertEqual(377, fibber.fib)
//            fibber.num = 18
//            XCTAssertEqual(2_584, fibber.fib)
//            fibber.num = 20
//            XCTAssertEqual(6_765, fibber.fib)
//            fibber.num = 25
//            XCTAssertEqual(75_025, fibber.fib)
//            fibber.num = 39
//            XCTAssertEqual(63_245_986, fibber.fib)
//        }
//    }
//
//    func testCautionaryTale() throws {
//
//    }
//
//    static var allTests = [
//        ("testMemoize", testMemoize),
//        ("testCautionaryTale", testCautionaryTale),
//    ]
//}
