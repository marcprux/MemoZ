//
//  MicroMemo
//  Memoize All The Things!
//
//  Marc Prud'hommeaux, 2020
//  MIT License
//

import Foundation

// MARK: MemoizationCache

/// A type-erased cache of memoization results, keyed on an arbitray `Hashable` and a cache key indicating the _source code location_ of the cache call.
/// - Note: this ideally would be a static stored property on `T`, but Swift doesn't support static stored properties on generic types.
/// - Seealso: https://stackoverflow.com/questions/37963327/what-is-a-good-alternative-for-static-stored-properties-of-generic-types-in-swif
@available(OSX 10.12, iOS 12, *)
public typealias MemoizationCache = Cache<SourceLocationCacheKey, Any>

/// A key for memoization that uses an arbitrary `Hashable` instance as well as the source code location (file name & line number) to uniquely identify a cache reference point.
public struct SourceLocationCacheKey : Hashable {
    let line: Int
    let file: String
    let subject: AnyHashable

    /// Internal-only key init – keys should be created only via `Hashable.memoize`
    @usableFromInline internal init(line: Int, file: String, subject: AnyHashable) {
        self.line = line
        self.file = file
        self.subject = subject
    }
}

@available(OSX 10.12, iOS 12, *)
public extension MemoizationCache {
    /// A single global cache of memoization results. The cache is thread-safe and backed by an `NSCache` for automatic memory management.
    /// - Seealso: `Hashable.memoize`
    static let shared = MemoizationCache()
}

extension Hashable {
    /// Memoize the result of the execution of a predicate for the `Hashable` receiver.
    ///
    /// The source subject (the receiver) and the result object (the return value) should be value types, and the `predicate` must be a *pure* function that captures *no state*, in that:
    ///
    /// 1. Its return value is the same for the same arguments (no variation with local static variables, non-local variables, mutable reference arguments or input streams from I/O devices).
    /// 2. Its evaluation has no side effects (no mutation of local static variables, non-local variables, mutable reference arguments or I/O streams).
    ///
    /// - Note: The calling function's source file and line are used as the cache key, so care must be taken to avoid having multiple calls to `memoize` occur from a single line of source code.
    ///
    /// - Parameters:
    ///   - cache: the shared cache to use; `nil` disables caching and simply returns the result of `predicate` directly
    ///   - sourceIdentifier: the source identifier; this is automatically filled in with the calling source code file, but customization can be performed to control the cache key
    ///   - sourceIndex: the index in the source identifier; this is automatically filled in with the calling source line, but customiztion can be performed to control the cache key (e.g., to avoid collision for multiple same-line calls)
    ///   - predicate: the function to execute with the predicate; it may be called zero or more times, and it must be a pure function (no references to other state; always repeatable with the same arguments, no side-effects)
    ///
    /// - Throws: re-throws and errors from `predicate`
    /// - Returns: the result from the `predicate`, either a previously cached value, or the result of executing the `predicate`
    @available(OSX 10.12, iOS 12, *)
    @inlinable public func memoize<T>(with cache: MemoizationCache? = MemoizationCache.shared, sourceIdentifier file: String = #file, sourceIndex line: Int = #line, _ predicate: (Self) throws -> T) rethrows -> T {

        // specifying a nil cache is a mechanism for bypassing caching altogether
        guard let cache = cache else {
            return try predicate(self)
        }

        let cacheKey = MemoizationCache.Key(line: line, file: file, subject: self)
        // dbg(cacheKey)

        // note exclusive=false to reduce locking overhead; this does mean that multiple threads might simultaneously memoize the same result, but the benefits of faster cache reads later outweighs the unlikly change of multiple simultaneous cache hits
        let cacheValue = try cache.fetch(key: cacheKey, exclusive: false) { _ in
            try predicate(self)
        }

        // we use `expecting` so we drop into a breakpoint when the value is unexpected (which shouldn't generally happen, but could be a result of mis-using the `memoize` (e.g., within a generic function)).
        return try expecting(cacheValue as? T) ?? predicate(self) // fallback to direct execution in case something goes wrong with the cache
    }
}

extension Hashable where Self : AnyObject {
    /// Using `memoize` with reference types is technically possible, but is considered a mis-use of the framework.
    /// This warning can be bypassed by specifying the `cache` argument, in which case the method will use `Hashable.memoize`.
    @available(*, deprecated, message: "memoize should not be used with reference types")
    public func memoize<T>(sourceIdentifier file: String = #file, sourceIndex line: Int = #line, _ predicate: (Self) throws -> T) rethrows -> T {
        try predicate(self) // just execute the predicate directly without any caching
    }
}


// MARK: Cache

/// Wrapper around `NSCache` that allows keys/values to be value types and has an atomic `fetch` option.
@available(OSX 10.12, iOS 12, *)
public final class Cache<Key : Hashable, Value> : ExpressibleByDictionaryLiteral {
    private typealias CacheType = NSCache<NSRef<Key>, Ref<Value?>>

    /// We work with an internal cache because “Extension of a generic Objective-C class cannot access the class's generic parameters at runtime”
    // public let cache = NSCache<Ref<Key>, Ref<Value>>()
    private let cache = CacheType()

    /// The lock we use for cache-level locking
    private var cacheLock = os_unfair_lock_s()

    //private let logger = LoggingDelegate()

    private class LoggingDelegate : NSObject, NSCacheDelegate {
        func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
            if let obj = obj as? Ref<Value> {
                print("evicting", obj.rawValue, "from", Cache<Key, Value>.self)
            } else {
                print("evicting", obj, "from", Cache<Key, Value>.self)
            }
        }
    }

    public init(name: String = "\(#file):\(#line)") {
        self.cache.name = name
        //self.cache.delegate = logger // fun for debugging
    }

    public init(dictionaryLiteral elements: (Key, Value)...) {
        //self.cache.delegate = logger // fun for debugging
        for (key, value) in elements {
            //cache.setObject(Ref(rawValue: value), forKey: Ref(rawValue: key))
            cache.setObject(Ref(rawValue: .init(value)), forKey: NSRef(rawValue: key))
        }
    }

    public subscript(key: Key) -> Value? {
        get {
            // return cache.object(forKey: Ref(rawValue: key))?.rawValue
            return cache.object(forKey: NSRef(rawValue: key))?.rawValue
        }

        set {
            if let newValue = newValue {
                // cache.setObject(Ref(rawValue: newValue), forKey: Ref(rawValue: key))
                cache.setObject(Ref(rawValue: .init(newValue)), forKey: NSRef(rawValue: key))
            } else {
                // cache.removeObject(forKey: Ref(rawValue: key))
                cache.removeObject(forKey: NSRef(rawValue: key))
            }
        }
    }

    /// Gets the instance from the cache, or `create`s it if is not present
    public func fetch(key: Key, exclusive: Bool, create: (Key) throws -> (Value)) rethrows -> Value {
        // cache is thread safe, so we don't need to sync; but one possible advantage of syncing is that two threads won't try to generate the value for the same key at the same time, but in an environment where we are pre-populating the cache from multiple threads, it is probably better to accept the multiple work items rather than cause the process to be serialized
        // This speeds up things like pre-parsing Categorized.json from 4319ms (when locked) to 2486ms (without locking)


        let keyRef = NSRef(rawValue: key) // NSCache requires that the key be an NSObject subclass

        // quick lockless check for the object; we will check again inside any exclusive block
        if let object = cache.object(forKey: keyRef)?.rawValue {
            return object
        }

        var lockOrValue: Ref<Value?>
        do {
            os_unfair_lock_lock(&cacheLock)
            defer { os_unfair_lock_unlock(&cacheLock) }

            if let lockValue = cache.object(forKey: keyRef) {
                if exclusive { objc_sync_enter(lockValue) } // line up behind the create() block
                defer { if exclusive { objc_sync_exit(lockValue) } }

                if let value = lockValue.rawValue {
                    return value
                } else {
                    lockOrValue = lockValue // empty value means use the ref as a lock
                }
            } else {
                lockOrValue = .init(rawValue: .none) // no value: create a new empty Ref (i.e., the lock)
                cache.setObject(lockOrValue, forKey: keyRef)
            }
        }

        do {
            // lock the object for creation
            if exclusive { objc_sync_enter(lockOrValue) }
            defer { if exclusive { objc_sync_exit(lockOrValue) } }

            let value = try create(key)
            //assert(!exclusive || lockOrValue.rawValue == nil)
            if exclusive {
                lockOrValue.rawValue = value // fill in the locked value's value
            }
            // when exclusive, we update the existing key; otherwise we overwrite with a new (unsynchronized) value
            let cacheValue = exclusive ? lockOrValue : .init(rawValue: value)

            cache.setObject(cacheValue, forKey: keyRef)
            return value
        }
    }

    /// Empties the cache.
    public func clear() {
        cache.removeAllObjects()
    }

    /// The maximum total cost that the cache can hold before it starts evicting objects.
    /// If 0, there is no total cost limit. The default value is 0.
    /// When you add an object to the cache, you may pass in a specified cost for the object, such as the size in bytes of the object. If adding this object to the cache causes the cache’s total cost to rise above totalCostLimit, the cache may automatically evict objects until its total cost falls below totalCostLimit. The order in which the cache evicts objects is not guaranteed.
    /// - Note: This is not a strict limit, and if the cache goes over the limit, an object in the cache could be evicted instantly, at a later point in time, or possibly never, all depending on the implementation details of the cache.
    public var totalCostLimit: Int {
        get { cache.totalCostLimit }
        set { cache.totalCostLimit = newValue }
    }

    /// The maximum number of objects the cache should hold.
    /// If 0, there is no count limit. The default value is 0.
    /// - Note: This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly, later, or possibly never, depending on the implementation details of the cache.
    public var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }
}

// MARK: Utilities

/// Expects that the given parameter is non-nil, and logs an error when it is nil. This can be used as a breakpoint for identifying unexpected nils without failing an assertion.
@usableFromInline func expecting<T>(_ value: T?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line) -> T? {
//    if value == nil {
//        dbg("unexpected empty value for", T.self, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
//    }
    return value
}


/// A reference wrapper around another type; this will typically be used to provide reference semantics for value types
/// https://github.com/apple/swift/blob/master/docs/OptimizationTips.rst#advice-use-copy-on-write-semantics-for-large-values
final class Ref<T> : RawRepresentable {
    public var rawValue: T
    @inlinable public init(rawValue v: T) { rawValue = v }
}

/// A box type that permits copy-on-write semantics for value types
/// https://github.com/apple/swift/blob/master/docs/OptimizationTips.rst#advice-use-copy-on-write-semantics-for-large-values
struct Box<T> {
    @usableFromInline var ref : Ref<T>
    @inlinable public init(_ x : T) { ref = Ref(rawValue: x) }

    @inlinable public var value: T {
        get { return ref.rawValue }
        set {
            if (!isKnownUniquelyReferenced(&ref)) {
                ref = Ref(rawValue: newValue)
                return
            }
            ref.rawValue = newValue
        }
    }
}

extension Ref : Equatable where T : Equatable { }

extension Box : Equatable where T : Equatable { }

extension Ref : Hashable where T : Hashable { }

extension Box : Hashable where T : Hashable { }

/// A reference that can be used as a cache key for `NSCache` that wraps a value type.
/// Simply using a `Ref` doesn't work (for unknown reasons).
@usableFromInline final class NSRef<RawValue: Hashable>: NSObject, RawRepresentable {
    @usableFromInline let rawValue: RawValue

    @usableFromInline init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    @inlinable override func isEqual(_ object: Any?) -> Bool {
        return (object as? NSRef<RawValue>)?.rawValue == self.rawValue
    }

    @inlinable static func ==(lhs: NSRef, rhs: NSRef) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    @inlinable override var hash: Int {
        return self.rawValue.hashValue
    }
}
