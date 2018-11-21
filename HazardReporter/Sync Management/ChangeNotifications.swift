import Foundation
import CloudKit

let recordDidChangeLocally = Notification.Name(rawValue: "social.Finch.HazardReporter.localChangeKey")
let recordDidChangeRemotely = Notification.Name(rawValue: "social.Finch.HazardReporter.remoteChangeKey")

enum RecordChange { //since record changes are mutually exclusive
    case created(CKRecord)
    case updated(CKRecord)
    case deleted(CKRecord.ID)
}
