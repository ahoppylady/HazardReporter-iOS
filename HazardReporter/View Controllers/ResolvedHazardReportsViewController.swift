import UIKit
import CloudKit

class ResolvedHazardReportsViewController:     UIViewController,
    UITableViewDataSource,
    UITableViewDelegate
{
    
    @IBOutlet weak var tableView: UITableView!
    var hazardReports = [HazardReport]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //local changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleLocalRecordChange),
                                               name: recordDidChangeLocally,
                                               object: nil) //need notification no matter which object posted it
        
        //remote changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRemoteRecordChange),
                                               name: recordDidChangeRemotely,
                                               object: nil) //need notification no matter which object posted it
        
        let predicate = NSPredicate(format: "isResolved == 1")
        let resolvedHazardsQuery = CKQuery(recordType: "HazardReport", predicate: predicate)
        
        // Sorting by modificationDate descending
        let modificationDateSortDescriptor = NSSortDescriptor(key: "modificationDate",
                                                              ascending: false)
        resolvedHazardsQuery.sortDescriptors = [modificationDateSortDescriptor]
        
        CKContainer.default().publicCloudDatabase.perform(resolvedHazardsQuery,
                                                          inZoneWith: nil)
        { (records, error) in
            // Safely unwrap records and assign to VC variable if not nil
            guard let records = records else {return}
            self.hazardReports = records.map { HazardReport(record: $0)}
            // Perform reload to get fresh data on the main thread
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: recordDidChangeLocally,
                                                  object: nil)
    }
    
    @objc func handleLocalRecordChange(_ notification: Notification) {
        guard let recordChange = notification.userInfo?["recordChange"] as? RecordChange else { return } //validated the key hasn't been mistyped
        processRecordChanges([recordChange])
    }
    
    @objc func handleRemoteRecordChange(_ notification: Notification) {
        CKContainer.default().fetchCloudKitRecordChanges() { changes in
            self.processRecordChanges(changes)
        }
    }
    
    func processRecordChanges(_ recordChanges: [RecordChange]) {
        for recordChange in recordChanges{
            switch recordChange {
            case .updated(let record):
                //find existing hazard report in the data source array
                let existingHazardReportIndex = self.hazardReports.index(where: { report in
                    report.cloudKitRecord.recordID.recordName == record.recordID.recordName
                })
                
                if let existingHazardReportIndex = existingHazardReportIndex {
                    let updatedHazardReport = HazardReport(record: record)
                    
                    if updatedHazardReport.isResolved == false {
                        self.hazardReports.remove(at: existingHazardReportIndex)
                    } else {
                        self.hazardReports[existingHazardReportIndex] = updatedHazardReport
                    }
                } else {
                    let newHazardReport = HazardReport(record: record)
                    guard newHazardReport.isResolved == true else { continue }
                    
                    self.hazardReports.append(newHazardReport)
                }
            case .deleted(let recordID):
                let existingHazardReportIndex = self.hazardReports.index(where: { report in
                    report.cloudKitRecord.recordID.recordName == recordID.recordName
                })
                
                if let existingHazardReportIndex = existingHazardReportIndex {
                    self.hazardReports.remove(at: existingHazardReportIndex)
                }
            default: continue
            }
        }
        self.hazardReports.sort { $0.cloudKitRecord.modificationDate! > $1.cloudKitRecord.modificationDate! }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    
    // MARK: TableView Data Source methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return self.hazardReports.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "hazardReportCell",
                                                 for: indexPath)
        
        let displayHazardReport = self.hazardReports[indexPath.row]
        
        // Display date as main text
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy"
        
        if let creationDate = displayHazardReport.creationDate {
            cell.textLabel?.text = dateFormatter.string(from: creationDate)
        }
        
        // Display description as detail text
        cell.detailTextLabel?.text = displayHazardReport.hazardDescription
        
        return cell
    }
    
    // MARK: TableView Delegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "resolvedHazardDetails":
            let destinationVC = segue.destination as! HazardReportDetailsViewController
            
            let selectedIndexPath = tableView.indexPathForSelectedRow!
            let selectedHazardReport = hazardReports[selectedIndexPath.row]
            
            destinationVC.hazardReport = selectedHazardReport
        default: break
        }
    }
    
}
