#if !os(watchOS) // XCTest not supported

import XCTest
import Dispatch
import MemoZ

extension Sequence where Element : Numeric {
    /// The sum of all the elements.
    /// - Complexity: O(N)
    var sum: Element { self.reduce(0, +) }
}

extension Sequence where Element : Numeric, Self : Hashable {
    /// The (memoized) sum of all the elements.
    /// - Complexity: Initial: O(N) MemoiZed: O(1)
    var sumZ: Element { self.memoz.sum }
}

private extension XCTestCase {
    /// Perform `XCTestCase.measure` for cases where a high standard deviation is expected; this works around an issue on non-macOS XCTest implementations where the maximum standard distribution is hardwired at 10%.
    func measureHighStddev(block: () -> ()) {
        #if !os(macOS)
        // unfortunately the open implementation of XCTest.measure hardwires the maximum permitted standard deviation to 10% (https://github.com/apple/swift-corelibs-xctest/blob/main/Sources/XCTest/Private/WallClockTimeMetric.swift#L33)
        // this undermines our tests that are designed to show that caching is working by showing a very high standard deviation; until this is fixed (or we re-implement `measure`), we need to skip some measure tests

        // simply execute the block itself 10 times…
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            // …without performing the measurements
            startMeasuring()
            stopMeasuring()
            block()
        }
        #else
        measure {
            block()
        }
        #endif
    }
}

// Measure the performance of non-memoized & memoized `sum`
class MemoZDemo: XCTestCase {
    /// A sequence of integers ranging from -1M through +1M
    let millions = (-1_000_000...1_000_000)

    func testCalculatedSum() {
        // average: 1.299, relative standard deviation: 0.509%, values: [1.312717, 1.296008, 1.306766, 1.298375, 1.299257, 1.303043, 1.296738, 1.294311, 1.288839, 1.293301]
        measure { XCTAssertEqual(millions.sum, 0) }
    }

    func testMemoizedSum() {
        // average: 0.133, relative standard deviation: 299.900%, values: [1.332549, 0.000051, 0.000018, 0.000032, 0.000110, 0.000021, 0.000016, 0.000015, 0.000014, 0.000123]
        measureHighStddev { XCTAssertEqual(millions.sumZ, 0) }
    }

    override func tearDown() {
        super.tearDown()
        MemoizationCache.shared.clear() // clear out the global cache
    }
}

extension Sequence where Element : Numeric {
    /// The product of all the elements.
    /// - Complexity: O(N)
    var product: Element { reduce(1, *) }
}

extension MemoZDemo {
    /// A bunch of random numbers from the given offset
    func rangeLimts(count: Int = 20, offset: Int = 1_000_000) -> [Int] {
        (0..<count).map({ $0 + offset }).shuffled()
    }

    func testCalculatedSumParallel() {
        let ranges = rangeLimts()
        measure { // average: 7.115, relative standard deviation: 3.274%, values: [6.579956, 6.785192, 7.074619, 7.123436, 7.242951, 7.295850, 7.326060, 7.285277, 7.249500, 7.187203]
            DispatchQueue.concurrentPerform(iterations: ranges.count) { i in
                XCTAssertEqual((-ranges[i]...ranges[i]).sum, 0)
            }
        }
    }

    func testMemoizedSumParallel() {
        let ranges = rangeLimts()
        measureHighStddev { // average: 0.671, relative standard deviation: 299.856%, values: [6.708572, 0.000535, 0.000298, 0.000287, 0.000380, 0.000400, 0.000337, 0.000251, 0.000225, 0.000183]
            DispatchQueue.concurrentPerform(iterations: ranges.count) { i in
                XCTAssertEqual((-ranges[i]...ranges[i]).sumZ, 0)
            }
        }
    }
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

extension String {
    /// Returns this string with a random UUID at the end
    var withRandomUUIDSuffix: String { self + UUID().uuidString }
}

final class MemoZTests: XCTestCase {
    /// This is an example of mis-use of the cache by caching a non-referrentially-transparent keypath function
    func testMisuse() {
        XCTAssertNotEqual("".withRandomUUIDSuffix, "".withRandomUUIDSuffix)
        XCTAssertEqual("".memoz.withRandomUUIDSuffix, "".memoz.withRandomUUIDSuffix) // two random IDs are the same!

        XCTAssertNotEqual("".memoz.withRandomUUIDSuffix, "xyz".memoz.withRandomUUIDSuffix)
        XCTAssertEqual("xyz".memoz.withRandomUUIDSuffix, "xyz".memoz.withRandomUUIDSuffix)
    }

    func testCacheCountLimit() throws {
        // mis-use the cache to show that the count limit will purge older references
        let cache = MemoizationCache(countLimit: 10)
        let randid = ""[memoz: cache].withRandomUUIDSuffix
        XCTAssertEqual(randid, ""[memoz: cache].withRandomUUIDSuffix)

        for i in 1...1000 {
            let _ = "\(i)"[memoz: cache].withRandomUUIDSuffix
        }

        #if !os(macOS)
        throw XCTSkip("count limit unsupported outside of macOS")
        #else
        XCTAssertNotEqual(randid, ""[memoz: cache].withRandomUUIDSuffix, "cache should have been purged")
        #endif
    }

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

    let millions = (-1_000_000)...(+1_000_000)

    func testSumCached() {
        measureHighStddev { // average: 0.129, relative standard deviation: 299.957%
            XCTAssertEqual(0, millions.memoz.sum)
        }
    }

    func testSumUncached() {
        measure { // average: 1.288, relative standard deviation: 1.363%
            XCTAssertEqual(0, millions.sum)
        }
    }

    struct Pointless : Hashable {
        var alwaysOne: Int { 1 }
        var alwaysOneZ: Int { memoz.alwaysOne }
    }

    func testPointlessComputation() {
        let pointless = Pointless()
        measure { // average: 0.013, relative standard deviation: 10.553%, values: [0.017202, 0.014706, 0.013114, 0.012666, 0.012782, 0.012689, 0.012770, 0.012431, 0.012440, 0.013157]
            for _ in 1...10_000 {
                XCTAssertEqual(1, pointless.alwaysOne)
            }
        }
    }

    func testPointlessMemoization() {
        let pointless = Pointless()
        measure { // average: 0.040, relative standard deviation: 3.971%, values: [0.043689, 0.039205, 0.038396, 0.041741, 0.038969, 0.039193, 0.039041, 0.039618, 0.038810, 0.038761]
            for _ in 1...10_000 {
                XCTAssertEqual(1, pointless.alwaysOneZ)
            }
        }
    }

    @available(*, deprecated) // so we don't get deprecation warnings for .memoz on AnyObject
    func testValueTypes() {
        let str = "xyz" as NSString
        XCTAssertEqual(3, (str as String).memoz.count)
        XCTAssertEqual("Xyz", (str as NSString).memoz.capitalized) // we should get a deprecation warning here
    }

    #if swift(>=5.3) // 5.3+ or else: struct declaration cannot close over value 'sumSequence' defined in outer scope
    func testLocalCalculation() {
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
                let from, to: Int
                var sum: Int { sumSequence(from: from, to: to) }
            }

            return Summer(from: from, to: to).memoz.sum
        }

        measureHighStddev { // average: 0.064, relative standard deviation: 299.894%, values: [0.641700, 0.000073, 0.000020, 0.000015, 0.000014, 0.000028, 0.000015, 0.000013, 0.000013, 0.000013]
            XCTAssertEqual(1500001500000, summit(from: 1_000_000, to: 2_000_000))
        }
    }
    #endif
    
    func testCachePartition() {
        let uuids = (0...100_000).map({ _ in UUID() })
        measure {
            // the following two calls are the same, except the second one uses a partitioned cache
            XCTAssertEqual(3800038, uuids.memoz.description.count)
            XCTAssertEqual(3800038, uuids.memoize(with: .domainCache, \.description).count)
            XCTAssertEqual(3800038, uuids[memoz: .domainCache].description.count)
        }
    }

    #if !os(Linux)
    func testJSONFormatted() {
        do {
            let xyz = ["x": "A", "y": "B", "z": "C"]
            let data = try xyz[JSONFormatted: false, sorted: true].get()
            XCTAssertEqual(String(data: data, encoding: .utf8), "{\"x\":\"A\",\"y\":\"B\",\"z\":\"C\"}")

            let _ = try xyz.memoz[JSONFormatted: false, sorted: nil].get()
            let _ = try xyz.memoz[JSONFormatted: true, sorted: false].get()
            let _ = try xyz.memoz[JSONFormatted: true, sorted: true].get()

            // ensure that keypath parameters are used in in the cached values
            XCTAssertEqual(try xyz.memoz[JSONFormatted: true, sorted: true].get(), try xyz.memoz[JSONFormatted: true, sorted: true].get())
            XCTAssertEqual(try xyz.memoz[JSONFormatted: false, sorted: false].get(), try xyz.memoz[JSONFormatted: false, sorted: false].get())

            XCTAssertNotEqual(try xyz.memoz[JSONFormatted: true, sorted: true].get(), try xyz.memoz[JSONFormatted: false, sorted: false].get(), "cache clash")
        } catch {
            XCTFail("\(error)")
        }
    }
    #endif

    func testFilterEager() {
        let million = 1...1_000_000
        measure { // average: 1.158, relative standard deviation: 0.909%, values: [1.172126, 1.171695, 1.160608, 1.159658, 1.162762, 1.155741, 1.134647, 1.162453, 1.150810, 1.149786]
            XCTAssertEqual(2, million.filter(\.isEven).first)
        }
    }

    func testFilterLazy() {
        let million = 1...1_000_000
        measure { // average: 0.000, relative standard deviation: 245.818%, values: [0.001246, 0.000049, 0.000024, 0.000021, 0.000020, 0.000043, 0.000027, 0.000020, 0.000020, 0.000019]
            XCTAssertEqual(2, million.lazy.filter(\.isEven).first)
        }
    }

    #if !os(Linux)
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
    #endif

    func testErrorHandling() {
        XCTAssertThrowsError(try Array<Bool>().memoz.firstAndLast.get())
    }
}

final class CacheTests: XCTestCase {
    func testCacheAPI() {
        let cache = Cache<Int, String>()

        func cachedDescription(for number: Int) -> String {
            cache.fetch(key: number, create: { key in
                String(describing: key)
            })
        }

        XCTAssertEqual("123", cachedDescription(for: 123))
        XCTAssertEqual("123", cachedDescription(for: 123)) // this will return the cached result
    }

    /// Tracker for testCacheKeyHits
    private static var testCacheKeyHitsCount = 0

    /// Ensures that a cache will successfully return the value for the given key
    func testCacheKeyHits() {
        let cache = Cache<UUID, String>()
        let key = UUID()
        var hitCount = Self.testCacheKeyHitsCount

        func fetch() -> String {
            cache.fetch(key: key) { key in
                Self.testCacheKeyHitsCount += 1
                return ""
            }
        }

        let _ = fetch()
        hitCount += 1
        XCTAssertEqual(1, Self.testCacheKeyHitsCount)

        for _ in 1...100 {
            let _ = fetch()
            // hitCount += 1 // should not increment!
            XCTAssertEqual(hitCount, Self.testCacheKeyHitsCount)
        }
    }

    func testParseCache() {
        let fr = Locale(identifier: "fr_FR").memoz[parseNumber: "1.234,987"]
        XCTAssertNotNil(fr)
        let en = Locale(identifier: "en_US").memoz[parseNumber: "1,234.9870"]
        XCTAssertNotNil(en)

        XCTAssertEqual(fr, en)
    }

}

extension Locale {
    subscript(parseNumber numericString: String) -> NSNumber? {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.isLenient = false
        fmt.locale = self
        return fmt.number(from: numericString)
    }
}

extension MemoizationCache {
    /// A domain-specific cache
    static let domainCache = MemoizationCache()
}

#if !os(Linux)
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
#endif

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


extension Sequence {
    /// Sorts the collection by the the given `keyPath` of the element
    subscript<T: Comparable>(sorting sortPath: KeyPath<Element, T>) -> [Element] {
        return self.sorted(by: {
            $0[keyPath: sortPath] < $1[keyPath: sortPath]
        })
    }
}

extension Array where Element: Collection & Hashable {
    /// "C", "BB", "AAA"
    var sortedByCountZ: [Element] {
        self.memoz[sorting: \.count]
    }
}

extension Array where Element: Comparable & Hashable {
    /// "AAA", "BB", "C"
    var sortedBySelfZ: [Element] {
        self.memoz[sorting: \.self]
    }
}

extension MemoZTests {
    func testMemoKeyedSubscript() {
        let strs = ["AAA", "C", "BB"]
        XCTAssertEqual(strs.sortedBySelfZ, ["AAA", "BB", "C"])
        XCTAssertEqual(strs.sortedByCountZ, ["C", "BB", "AAA"])
    }
}

#endif // !os(watchOS)
