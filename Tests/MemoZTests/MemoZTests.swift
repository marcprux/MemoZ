
import XCTest
import Dispatch
import MemoZ

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
            XCTAssertEqual(3800038, uuids[memoz: .domainCache].description.count)
        }
    }

    func testJSONFormatted() throws {
        let data = try ["x": "A", "y": "B", "z": "C"][JSONFormatted: false, sorted: true].get()
        XCTAssertEqual(String(data: data, encoding: .utf8), "{\"x\":\"A\",\"y\":\"B\",\"z\":\"C\"}")

        let data2 = try ["x": "A", "y": "B", "z": "C"].memoz[JSONFormatted: false, sorted: nil].get()

    }

    func testCacheThreading() {
        // make a big map with some duplicated UUIDs
        var uuids = (1...10).map({ _ in [[UUID()]] })
        for _ in 1...12 {
            uuids += uuids
        }
        uuids.shuffle()

        XCTAssertEqual(40960, uuids.count)
        print("checking cache for \(uuids.count) random UUIDs")

        func checkUUID(at index: Int) {
            let pretty = Bool.random()
            let str1 = uuids[index].memoz[JSONFormatted: pretty]
            let str2 = uuids[index].memoz[JSONFormatted: !pretty, sorted: true]
            // make sure the two memoz were keyed on different parameters
            XCTAssertNotEqual(try str1.get(), try str2.get())
        }

        measure {
            DispatchQueue.concurrentPerform(iterations: uuids.count, execute: checkUUID)
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

extension Encodable {
    /// A JSON blob with the given parameters.
    ///
    /// For example:
    /// ```["x": "A", "y": "B", "z": "C"][JSONFormatted: false, sorted: true]```
    ///
    /// will return the result with data:
    ///
    /// ```{"x":"A","y":"B","z":"C"}```
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
