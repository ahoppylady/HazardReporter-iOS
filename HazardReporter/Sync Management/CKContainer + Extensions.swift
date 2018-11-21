import Foundation
import CloudKit
import UIKit

extension CKContainer {
    func fetchCloudKitRecordChanges(completion: @escaping ([RecordChange])-> ()) {
        // Get existing change token
        let existingChangeToken = UserDefaults().serverChangeToken
        // CKFetchNotificationChanges
        let notificationChangesOpertation = CKFetchNotificationChangesOperation(previousServerChangeToken: existingChangeToken)
        // Cache change reasons
        var changeReasons = [CKRecord.ID: CKQueryNotification.Reason]()
        notificationChangesOpertation.notificationChangedBlock = { notification in
            if let n = notification as? CKQueryNotification, let recordID = n.recordID {
            
            changeReasons[recordID] = n.queryNotificationReason
            }
        }
        // Implement CKFetchNotificationChanges's completion block
        notificationChangesOpertation.fetchNotificationChangesCompletionBlock = { newChangeToken, error in
            guard error == nil else { return }
            guard changeReasons.count > 0 else { return }
            
            // Save new change token
            UserDefaults().serverChangeToken = newChangeToken
            
            // Split deleted record IDs from inserted/updated
            var deletedIDs = [CKRecord.ID]()
            var insertedOrUpdatedIDs = [CKRecord.ID]()
            
            for (recordID, reason) in changeReasons {
                switch reason{
                case .recordDeleted:
                    deletedIDs.append(recordID)
                
                default:
                    insertedOrUpdatedIDs.append(recordID)
                }
            }
            
            // Fetch inserted/updated records based on their record IDs
            let fetchRecordsOperation = CKFetchRecordsOperation(recordIDs: insertedOrUpdatedIDs)
            fetchRecordsOperation.fetchRecordsCompletionBlock = { records, error in
                // Create on array of record changes using the Record Change Enum
                var changes: [RecordChange] = deletedIDs.map { RecordChange.deleted($0) }
                
                for (id, record) in records ?? [:] {
                    guard let reason = changeReasons[id] else { continue }
                    
                    switch reason{
                    case .recordCreated:
                        changes.append(RecordChange.created(record))
                        
                    case .recordUpdated:
                        changes.append(RecordChange.updated(record))
                        
                    default:
                        fatalError("Inserts and updates only in this block")
                    }
                 }
                
                // Pass the completed [RecordChange] back to whoever started this whole process through completion closure
                completion(changes)
            }
            // Add operation to database
            self.publicCloudDatabase.add(fetchRecordsOperation)
        }
        // Kick everything off by adding fetch notifications operation to the CKContainer
        self.add(notificationChangesOpertation )
    }
        
}

public extension UserDefaults {
    // https://gist.github.com/ralcr/ce69a5a496e6619143a639ec55105e98
    var serverChangeToken: CKServerChangeToken? {
        get {
            guard let data = self.value(forKey: "ChangeToken") as? Data else {
                return nil
            }
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                return nil
            }
            
            return token
        }
        set {
            if let token = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "ChangeToken")
                self.synchronize()
            } else {
                self.removeObject(forKey: "ChangeToken")
            }
        }
    }
}
