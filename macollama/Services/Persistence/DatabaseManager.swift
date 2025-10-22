import Foundation
import SQLite3
#if os(macOS)
import AppKit
let dbFilename:String = "macollama.sqlite"
#elseif os(iOS)
import UIKit
let dbFilename:String = "ollama_chat.sqlite"
#endif

enum DatabaseError: Error {
    case connectionFailed
    case prepareFailed
    case executeFailed
    case queryFailed
    case connectionError
    case executionError(String)
}

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(dbFilename)
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            createTable()
        } else {
            print("Database connection failed")
        }
    }
    
    private func createTable() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS questions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          groupid TEXT NOT NULL,
          instruction TEXT,
          question TEXT,
          answer TEXT,
          image TEXT,
          created TEXT,
          engine TEXT,
          title TEXT,
          provider TEXT,
          model TEXT
        );
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        
        sqlite3_finalize(statement)
        
        // Add title column to existing databases if it doesn't exist
//        let addTitleColumnQuery = "ALTER TABLE questions ADD COLUMN title TEXT;"
//        var alterStatement: OpaquePointer?
//        if sqlite3_prepare_v2(db, addTitleColumnQuery, -1, &alterStatement, nil) == SQLITE_OK {
//            sqlite3_step(alterStatement) // This will fail if column already exists, which is fine
//        }
//        sqlite3_finalize(alterStatement)
        
        // Add provider column to existing databases if it doesn't exist
//        let addProviderColumnQuery = "ALTER TABLE questions ADD COLUMN provider TEXT;"
//        var alterProviderStatement: OpaquePointer?
//        if sqlite3_prepare_v2(db, addProviderColumnQuery, -1, &alterProviderStatement, nil) == SQLITE_OK {
//            sqlite3_step(alterProviderStatement) // This will fail if column already exists, which is fine
//        }
//        sqlite3_finalize(alterProviderStatement)
        
        // Add model column to existing databases if it doesn't exist
//        let addModelColumnQuery = "ALTER TABLE questions ADD COLUMN model TEXT;"
//        var alterModelStatement: OpaquePointer?
//        if sqlite3_prepare_v2(db, addModelColumnQuery, -1, &alterModelStatement, nil) == SQLITE_OK {
//            sqlite3_step(alterModelStatement) // This will fail if column already exists, which is fine
//        }
//        sqlite3_finalize(alterModelStatement)
        
        // Fix typo in existing provider data (migrate "Ollma" to "Ollama")
        //migrateProviderTypo()
        
        //insertInitialDataIfNeeded()
    }
    
//    private func migrateProviderTypo() {
//        // Fix the typo "Ollma" to "Ollama" in existing database records
//        let updateQuery = "UPDATE questions SET provider = 'Ollama' WHERE provider = 'Ollma';"
//        var statement: OpaquePointer?
//        
//        if sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK {
//            sqlite3_step(statement)
//            let changes = sqlite3_changes(db)
//            if changes > 0 {
//                print("Migrated \(changes) records from 'Ollma' to 'Ollama'")
//            }
//        }
//        sqlite3_finalize(statement)
//    }
    
    private func insertInitialDataIfNeeded() {
        do {
            let uuid = UUID().uuidString
            let results = try fetchTitles()
            guard results.isEmpty else { return }

            let initialData = [
                ("l_q1", "l_a1"),
                ("l_q2", "l_a2"),
                ("l_q3", "l_a3")
            ]

            for (question, answer) in initialData {
                try insert(
                    groupId: uuid,
                    instruction: "",
                    question: question.localized,
                    answer: answer.localized,
                    image: nil,
                    engine: "LLM-Bridge"
                )
            }
        } catch {
            // Log error but don't throw as this is optional initial data
            #if DEBUG
            print("Failed to insert initial data: \(error)")
            #endif
        }
    }
        
    func insert(groupId: String, instruction: String?, question: String, answer: String, image: PlatformImage?, engine: String, provider: String? = nil, model: String? = nil) throws {
        let insertSQL = """
            INSERT INTO questions (groupid, instruction, question, answer, image, created, engine, title, provider, model)
            VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?);
            """
        
        var statement: OpaquePointer?
        
        let dateFormatter = ISO8601DateFormatter()
        let currentTime = dateFormatter.string(from: Date())
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        var imageBase64: String? = nil
        if let image = image {
            #if os(macOS)
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                imageBase64 = jpegData.base64EncodedString()
            }
            #elseif os(iOS)
            if let jpegData = image.jpegData(compressionQuality: 0.7) {
                imageBase64 = jpegData.base64EncodedString()
            }
            #endif
        }
        
        sqlite3_bind_text(statement, 1, (groupId as NSString).utf8String, -1, nil)
        
        if let instruction = instruction {
            sqlite3_bind_text(statement, 2, (instruction as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        
        sqlite3_bind_text(statement, 3, (question as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (answer as NSString).utf8String, -1, nil)
        
        if let imageBase64 = imageBase64 {
            sqlite3_bind_text(statement, 5, (imageBase64 as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        sqlite3_bind_text(statement, 6, (currentTime as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 7, (engine as NSString).utf8String, -1, nil)
        
        // Bind provider parameter (position 8)
        if let provider = provider {
            sqlite3_bind_text(statement, 8, (provider as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        // Bind model parameter (position 9)
        if let model = model {
            sqlite3_bind_text(statement, 9, (model as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 9)
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    func fetchTitles() throws -> [(id: Int, groupId: String, instruction: String?, question: String, answer: String, image: String?, created: String, engine: String, title: String?, provider: String?, model: String?)] {
        let query = """
            SELECT q1.id, q1.groupid, q1.instruction, q1.question, q1.answer, q1.image, q1.created, q1.engine, q1.title, q1.provider, q1.model 
            FROM questions q1
            INNER JOIN (
                SELECT groupid, MIN(id) as min_id, MAX(created) as max_created
                FROM questions 
                GROUP BY groupid
            ) q2 ON q1.groupid = q2.groupid AND q1.id = q2.min_id
            ORDER BY q2.max_created DESC;
        """
        var statement: OpaquePointer?
        var results: [(id: Int, groupId: String, instruction: String?, question: String, answer: String, image: String?, created: String, engine: String, title: String?, provider: String?, model: String?)] = []
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let groupId = String(cString: sqlite3_column_text(statement, 1))
            let instruction = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let question = String(cString: sqlite3_column_text(statement, 3))
            let answer = String(cString: sqlite3_column_text(statement, 4))
            let image = sqlite3_column_text(statement, 5).map { String(cString: $0) }
            let created = String(cString: sqlite3_column_text(statement, 6))
            let engine = String(cString: sqlite3_column_text(statement, 7))
            let title = sqlite3_column_text(statement, 8).map { String(cString: $0) }
            let provider = sqlite3_column_text(statement, 9).map { String(cString: $0) }
            let model = sqlite3_column_text(statement, 10).map { String(cString: $0) }
            
            results.append((id, groupId, instruction, question, answer, image, created, engine, title, provider, model))
        }
        
        sqlite3_finalize(statement)
        return results
    }

    
    func fetchAllQuestions() throws -> [(id: Int, groupId: String, instruction: String?, question: String, answer: String, image: String?, created: String, engine: String)] {
        let query = "SELECT * FROM questions ORDER BY created DESC;"
        var statement: OpaquePointer?
        var results: [(id: Int, groupId: String, instruction: String?, question: String, answer: String, image: String?, created: String, engine: String)] = []
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let groupId = String(cString: sqlite3_column_text(statement, 1))
            let instruction = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let question = String(cString: sqlite3_column_text(statement, 3))
            let answer = String(cString: sqlite3_column_text(statement, 4))
            let image = sqlite3_column_text(statement, 5).map { String(cString: $0) }
            let created = String(cString: sqlite3_column_text(statement, 6))
            let engine = String(cString: sqlite3_column_text(statement, 7))
            
            results.append((id, groupId, instruction, question, answer, image, created, engine))
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func update(id: Int, answer: String) throws {
        let updateQuery = "UPDATE questions SET answer = ? WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        sqlite3_bind_text(statement, 1, (answer as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(id))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    func updateChatName(groupId: String, newName: String) throws {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Cannot set empty chat name")
            throw DatabaseError.executeFailed
        }
        
//        // First, let's check what records exist for this groupId
//        let checkQuery = "SELECT id, question FROM questions WHERE groupid = ? ORDER BY id ASC;"
//        var checkStatement: OpaquePointer?
//        
//        //print("Checking existing records for groupId: \(groupId)")
//        
//        if sqlite3_prepare_v2(db, checkQuery, -1, &checkStatement, nil) == SQLITE_OK {
//            sqlite3_bind_text(checkStatement, 1, (groupId as NSString).utf8String, -1, nil)
//            
//            while sqlite3_step(checkStatement) == SQLITE_ROW {
//                let id = Int(sqlite3_column_int(checkStatement, 0))
//                let question = String(cString: sqlite3_column_text(checkStatement, 1))
//                //print("  Found record: id=\(id), question='\(question)'")
//            }
//        }
//        sqlite3_finalize(checkStatement)
        
        // Now perform the update - update the title field of the first message in the group
        let updateQuery = "UPDATE questions SET title = ? WHERE groupid = ? AND id = (SELECT MIN(id) FROM questions WHERE groupid = ?);"
        var statement: OpaquePointer?
        
        //print("Updating chat name for groupId: \(groupId) to: '\(newName)'")
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            print("Failed to prepare update statement")
            throw DatabaseError.prepareFailed
        }
        
        sqlite3_bind_text(statement, 1, (newName as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (groupId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (groupId as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            print("Failed to execute update statement, result: \(result)")
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed
        }
        
        //let changes = sqlite3_changes(db)
        //print("Update completed, rows affected: \(changes)")
        
        sqlite3_finalize(statement)
        
        // Verify the update worked
        //print("Verifying update...")
//        if sqlite3_prepare_v2(db, checkQuery, -1, &checkStatement, nil) == SQLITE_OK {
//            sqlite3_bind_text(checkStatement, 1, (groupId as NSString).utf8String, -1, nil)
//            
//            while sqlite3_step(checkStatement) == SQLITE_ROW {
//                let id = Int(sqlite3_column_int(checkStatement, 0))
//                let question = String(cString: sqlite3_column_text(checkStatement, 1))
//                //print("  After update: id=\(id), question='\(question)'")
//            }
//        }
//        sqlite3_finalize(checkStatement)
    }
    
    func delete(id: Int) throws {
        let originalId = id % 2 == 0 ? id/2 : (id-1)/2
        
        let deleteQuery = "DELETE FROM questions WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        sqlite3_bind_int(statement, 1, Int32(originalId))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed
        }
        
        sqlite3_finalize(statement)
    }

    

    func fetchQuestionsByGroupId(_ groupId: String) throws -> [(id: Int, question: String, answer: String, created: String, image: String?, engine: String)] {
        //print("Fetching questions for groupId: \(groupId)")
        let query = """
            SELECT id, question, answer, created, image, engine 
            FROM questions
            WHERE groupid = ?
            ORDER BY id ASC;
            """
        
        var statement: OpaquePointer?
        var results: [(id: Int, question: String, answer: String, created: String, image: String?, engine: String)] = []
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        sqlite3_bind_text(statement, 1, (groupId as NSString).utf8String, -1, nil)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let question = String(cString: sqlite3_column_text(statement, 1))
            let answer = String(cString: sqlite3_column_text(statement, 2))
            let created = String(cString: sqlite3_column_text(statement, 3))
            let image = sqlite3_column_text(statement, 4).map { String(cString: $0) }
            let engine = String(cString: sqlite3_column_text(statement, 5))

            //print("Found message: id=\(id), question='\(question.prefix(30))...', answer='\(answer.prefix(30))...', created=\(created)")
            results.append((id, question, answer, created, image, engine))
        }
        
        sqlite3_finalize(statement)
        //print("Returning \(results.count) results for groupId: \(groupId)")
        return results
    }
    
    // Update provider and model for a chat group (first message in the group)
    func updateChatProviderAndModel(groupId: String, provider: String?, model: String?) throws {
        let updateQuery = """
            UPDATE questions 
            SET provider = ?, model = ? 
            WHERE groupid = ? AND id = (SELECT MIN(id) FROM questions WHERE groupid = ?);
        """
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        if let provider = provider {
            sqlite3_bind_text(statement, 1, (provider as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 1)
        }
        
        if let model = model {
            sqlite3_bind_text(statement, 2, (model as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        
        sqlite3_bind_text(statement, 3, (groupId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (groupId as NSString).utf8String, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    // Get provider and model for a chat group
    func getChatProviderAndModel(groupId: String) throws -> (provider: String?, model: String?) {
        let query = """
            SELECT provider, model 
            FROM questions 
            WHERE groupid = ? AND id = (SELECT MIN(id) FROM questions WHERE groupid = ?)
            LIMIT 1;
        """
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        sqlite3_bind_text(statement, 1, (groupId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (groupId as NSString).utf8String, -1, nil)
        
        var provider: String? = nil
        var model: String? = nil
        
        if sqlite3_step(statement) == SQLITE_ROW {
            provider = sqlite3_column_text(statement, 0).map { String(cString: $0) }
            model = sqlite3_column_text(statement, 1).map { String(cString: $0) }
        }
        
        sqlite3_finalize(statement)
        return (provider, model)
    }

    func deleteGroupChats(groupId: String) throws {
        let deleteQuery = "DELETE FROM questions WHERE groupid = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        sqlite3_bind_text(statement, 1, (groupId as NSString).utf8String, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed
        }
        
        sqlite3_finalize(statement)
    }

    func searchMessages(keyword: String) throws -> [(id: Int, groupId: String, question: String, answer: String, created: String, engine: String, image: String?, title: String?, provider: String?, model: String?)] {
        let pattern = "%\(keyword)%"
        
        let query = """
            SELECT id, groupid, question, answer, created, engine, image, title, provider, model
            FROM questions
            WHERE question LIKE ? OR answer LIKE ? OR title LIKE ?
            ORDER BY created DESC;
        """
        
        var statement: OpaquePointer?
        var results: [(id: Int, groupId: String, question: String, answer: String, created: String, engine: String, image: String?, title: String?, provider: String?, model: String?)] = []
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        sqlite3_bind_text(statement, 1, (pattern as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (pattern as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (pattern as NSString).utf8String, -1, nil)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let groupId = String(cString: sqlite3_column_text(statement, 1))
            let question = String(cString: sqlite3_column_text(statement, 2))
            let answer = String(cString: sqlite3_column_text(statement, 3))
            let created = String(cString: sqlite3_column_text(statement, 4))
            let engine = String(cString: sqlite3_column_text(statement, 5))
            let image = sqlite3_column_text(statement, 6).map { String(cString: $0) }
            let title = sqlite3_column_text(statement, 7).map { String(cString: $0) }
            let provider = sqlite3_column_text(statement, 8).map { String(cString: $0) }
            let model = sqlite3_column_text(statement, 9).map { String(cString: $0) }
            
            results.append((id, groupId, question, answer, created, engine, image, title, provider, model))
        }
        
        sqlite3_finalize(statement)
        return results
    }

    func deleteAllData() throws {
        let deleteSQL = "DELETE FROM questions;"
        var statement: OpaquePointer?
        
        guard let db = db else {
            throw DatabaseError.connectionError
        }
        
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            sqlite3_finalize(statement)
            throw DatabaseError.executeFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    // DEBUG: Helper function to inspect all data in the database
    func debugInspectDatabase() {
        print("=== DEBUG: Database Inspection ===")
        let query = "SELECT id, groupid, question, provider, model FROM questions ORDER BY groupid, id;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("Failed to prepare debug query")
            return
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let groupId = String(cString: sqlite3_column_text(statement, 1))
            let question = String(cString: sqlite3_column_text(statement, 2))
            let provider = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? "nil"
            let model = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? "nil"
            
            print("ID: \(id), GroupID: \(groupId), Question: \(question.prefix(30))..., Provider: \(provider), Model: \(model)")
        }
        
        sqlite3_finalize(statement)
        print("=== End Database Inspection ===")
    }
    
    // DEBUG: Force update a specific record for testing
    func debugForceUpdateProviderModel(groupId: String, provider: String, model: String) {
        let updateQuery = "UPDATE questions SET provider = ?, model = ? WHERE groupid = ?;"
        var statement: OpaquePointer?
        
        print("DEBUG: Force updating groupId \(groupId) to provider: \(provider), model: \(model)")
        
        guard sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK else {
            print("Failed to prepare force update query")
            return
        }
        
        sqlite3_bind_text(statement, 1, (provider as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (model as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (groupId as NSString).utf8String, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_DONE {
            let changes = sqlite3_changes(db)
            print("DEBUG: Force update completed, rows affected: \(changes)")
        } else {
            print("DEBUG: Force update failed")
        }
        
        sqlite3_finalize(statement)
    }
    
    // DEBUG: Check database schema
    func debugInspectSchema() {
        print("=== DEBUG: Database Schema ===")
        let query = "PRAGMA table_info(questions);"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("Failed to prepare schema query")
            return
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let columnId = Int(sqlite3_column_int(statement, 0))
            let columnName = String(cString: sqlite3_column_text(statement, 1))
            let columnType = String(cString: sqlite3_column_text(statement, 2))
            let notNull = sqlite3_column_int(statement, 3)
            let defaultValue = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? "NULL"
            let primaryKey = sqlite3_column_int(statement, 5)
            
            print("Column \(columnId): \(columnName) \(columnType) (NotNull: \(notNull), Default: \(defaultValue), PK: \(primaryKey))")
        }
        
        sqlite3_finalize(statement)
        print("=== End Database Schema ===")
    }
    
    // DEBUG: Easy test function - call this manually with a real groupId
    func debugTestProviderModelUpdate(groupId: String) {
        print("\n🔧 Testing provider/model update for groupId: \(groupId)")
        
        // Show current state
        do {
            let (currentProvider, currentModel) = try getChatProviderAndModel(groupId: groupId)
            print("BEFORE: provider=\(currentProvider ?? "nil"), model=\(currentModel ?? "nil")")
        } catch {
            print("Error getting current state: \(error)")
        }
        
        // Force update
        debugForceUpdateProviderModel(groupId: groupId, provider: "Ollama", model: "test-model")
        
        // Show updated state
        do {
            let (updatedProvider, updatedModel) = try getChatProviderAndModel(groupId: groupId)
            print("AFTER: provider=\(updatedProvider ?? "nil"), model=\(updatedModel ?? "nil")")
            
            if updatedProvider == "Ollama" && updatedModel == "test-model" {
                print("✅ SUCCESS: Provider/model update and retrieval works correctly!")
            } else {
                print("❌ FAILED: Values don't match what was saved")
            }
        } catch {
            print("Error getting updated state: \(error)")
        }
    }
    
    // DEBUG: Test with a real model name
    func debugTestProviderModelUpdateWithRealModel(groupId: String, model: String) {
        print("\n🔧 Testing provider/model update with REAL model: \(model)")
        
        // Show current state
        do {
            let (currentProvider, currentModel) = try getChatProviderAndModel(groupId: groupId)
            print("BEFORE: provider=\(currentProvider ?? "nil"), model=\(currentModel ?? "nil")")
        } catch {
            print("Error getting current state: \(error)")
        }
        
        // Force update with real model
        debugForceUpdateProviderModel(groupId: groupId, provider: "Ollama", model: model)
        
        // Show updated state
        do {
            let (updatedProvider, updatedModel) = try getChatProviderAndModel(groupId: groupId)
            print("AFTER: provider=\(updatedProvider ?? "nil"), model=\(updatedModel ?? "nil")")
            
            if updatedProvider == "Ollama" && updatedModel == model {
                print("✅ SUCCESS: Provider/model update with real model works!")
                print("🎯 The database layer is working correctly. Issue is likely in UI synchronization.")
            } else {
                print("❌ FAILED: Values don't match what was saved")
            }
        } catch {
            print("Error getting updated state: \(error)")
        }
    }
}
