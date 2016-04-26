//
//  FMDatabaseAdditionsVariadic.swift
//  FMDB
//

import Foundation

extension FMDatabase {
    
    /// Private generic function used for the variadic renditions of the FMDatabaseAdditions methods
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The NSArray of the arguments to be bound to the ? placeholders in the SQL.
    /// - parameter completionHandler:  The closure to be used to call the appropriate FMDatabase method to return the desired value.
    ///
    /// - returns:                      This returns the T value if value is found. Returns nil if column is NULL or upon error.
    
    private func valueForQuery<T>(sql: String, values: [AnyObject], completionHandler:(FMResultSet)->(T?)) -> T? {
        var result: T?
        
        if let rs = executeQuery(sql, withArgumentsInArray: values) {
            if rs.next() {
                let obj: AnyObject! = rs.objectForColumnIndex(0)
                if !(obj is NSNull) {
                    result = completionHandler(rs)
                }
            }
            rs.close()
        }
        
        return result
    }
    
    /// This is a rendition of stringForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:                      This returns string value if value is found. Returns nil if column is NULL or upon error.
    
    public func stringForQuery(sql: String, _ values: AnyObject...) -> String? {
        return valueForQuery(sql, values: values) { $0.stringForColumnIndex(0) }
    }
    
    /// This is a rendition of intForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:       This returns integer value if value is found. Returns nil if column is NULL or upon error.
    
    public func intForQuery(sql: String, _ values: AnyObject...) -> Int32? {
        return valueForQuery(sql, values: values) { $0.intForColumnIndex(0) }
    }
    
    /// This is a rendition of longForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:                      This returns long value if value is found. Returns nil if column is NULL or upon error.
    
    public func longForQuery(sql: String, _ values: AnyObject...) -> Int? {
        return valueForQuery(sql, values: values) { $0.longForColumnIndex(0) }
    }
    
    /// This is a rendition of boolForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:                      This returns Bool value if value is found. Returns nil if column is NULL or upon error.
    
    public func boolForQuery(sql: String, _ values: AnyObject...) -> Bool? {
        return valueForQuery(sql, values: values) { $0.boolForColumnIndex(0) }
    }
    
    /// This is a rendition of doubleForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:                      This returns Double value if value is found. Returns nil if column is NULL or upon error.
    
    public func doubleForQuery(sql: String, _ values: AnyObject...) -> Double? {
        return valueForQuery(sql, values: values) { $0.doubleForColumnIndex(0) }
    }
    
    /// This is a rendition of dateForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:                      This returns NSDate value if value is found. Returns nil if column is NULL or upon error.
    
    public func dateForQuery(sql: String, _ values: AnyObject...) -> NSDate? {
        return valueForQuery(sql, values: values) { $0.dateForColumnIndex(0) }
    }
    
    /// This is a rendition of dataForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:                      This returns NSData value if value is found. Returns nil if column is NULL or upon error.
    
    public func dataForQuery(sql: String, _ values: AnyObject...) -> NSData? {
        return valueForQuery(sql, values: values) { $0.dataForColumnIndex(0) }
    }
    
    /// This is a rendition of objectForQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// - parameter sql:                The SQL statement to be used.
    /// - parameter values:             The values to be bound to the ? placeholders
    ///
    /// - returns:                      This returns an object value if value is found. Returns nil if column is NULL or upon error.
    
    public func objectForQuery(sql: String, _ values: AnyObject...) -> AnyObject? {
        return valueForQuery(sql, values: values) { $0.objectForColumnIndex(0) }
    }

    public func dictionaryForQuery(sql: String, _ values: AnyObject...) -> [String: AnyObject]? {
        
        guard let rs = executeQuery(sql, withArgumentsInArray: values) else {
            return nil
        }
        
        var row : [String: AnyObject]?
        
        if rs.next() {
            row = [String: AnyObject]()
            for idx in 0..<rs.columnCount() {
                if let obj = rs.objectForColumnIndex(0) where !(obj is NSNull) {
                    row![rs.columnNameForIndex(idx)] = obj
                }
            }
        }
        rs.close()
        
        return row
    }
    
    public func arrayForQuery(sql: String, _ values: AnyObject...) -> [AnyObject?]? {
        
        guard let rs = executeQuery(sql, withArgumentsInArray: values) else {
            return nil
        }
        
        var row : [AnyObject?]?
        
        if rs.next() {
            row = [AnyObject?](count: Int(rs.columnCount()), repeatedValue: nil)
            for idx in 0..<rs.columnCount() {
                if let obj = rs.objectForColumnIndex(idx) where !(obj is NSNull) {
                    row![Int(idx)] = obj
                }
                else {
                    row![Int(idx)] = nil
                }
            }
        }
        rs.close()
        
        return row
    }
    
}
