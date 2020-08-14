
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
        XCTAssertEqual(15, (1...5).mmz.sum)
        XCTAssertEqual(120, (1...5).product)
        XCTAssertEqual(120, (1...5).mmz.product)
        XCTAssertEqual(true, 87178291199.isPrime)

        XCTAssertEqual(false, UInt64(3314192745739 - 1).isPrime)
        XCTAssertEqual(true, UInt64(3314192745739).isPrime)
        XCTAssertEqual(false, UInt64(3314192745739 + 1).isPrime)

        //XCTAssertEqual(true, UInt64(3331113965338635107).isPrime) // 1,133 seconds!
        XCTAssertEqual(false, 1002.isPrime)

        XCTAssertEqual(false, 1002.mmz.isPrime)

    }
}
