import UIKit
import CloudKit

class ActiveHazardReportsViewController:    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate
{
    var hazardReports = [HazardReport]()
    @IBOutlet weak var tableView: UITableView!
    
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

        let predicate = NSPredicate(format: "isResolved == 0")
        let activeHazardsQuery = CKQuery(recordType: "HazardReport", predicate: predicate)
        
        //Sorting by creationDate ascending
        let creationDateSortDescriptor = NSSortDescriptor(key: "creationDate", ascending: true)
        activeHazardsQuery.sortDescriptors = [creationDateSortDescriptor]
        
        CKContainer.default().publicCloudDatabase.perform(activeHazardsQuery,inZoneWith: nil) { (records, error) in
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
        self.processChanges([recordChange])
    }
    
    @objc func handleRemoteRecordChange(_ notification: Notification) {
        // fetch changes
        // process changes
        // updateUI
        CKContainer.default().fetchCloudKitRecordChanges() { changes in
            self.processChanges(changes)
        }
    }
    
    func processChanges(_ recordChanges: [RecordChange]) {
        for recordChange in recordChanges {
            switch recordChange {
            case .created(let createdCKRecord):
                //initialize new hazard report and guard to ensure it isn't already resolved
                let newHazardReport = HazardReport(record: createdCKRecord)
                guard newHazardReport.isResolved == false else { break }
                
                //append to the tableview's array
                self.hazardReports.append(newHazardReport)
                
            case .updated(let updatedCKRecord):
                //find existing hazard report in the data source array
                let existingHazardReportIndex = self.hazardReports.index { (report) -> Bool in
                    report.cloudKitRecord.recordID.recordName == updatedCKRecord.recordID.recordName
                }
                //remove if updated hazard report is now resolved
                
                if let existingIndex = existingHazardReportIndex {
                    let updatedHazardReport = HazardReport(record: updatedCKRecord)
                    
                    if updatedHazardReport.isResolved {
                        self.hazardReports.remove(at: existingIndex)
                    } else {
                        //else replace hazard report at that index in the array
                        self.hazardReports[existingIndex] = updatedHazardReport
                    }
                }
            case .deleted(let deletedCKRecordID):
                //find existing hazard report in the data source array
                let existingHazardReportIndex = self.hazardReports.index { (report) -> Bool in
                    report.cloudKitRecord.recordID.recordName == deletedCKRecordID.recordName
                }
                //when match is found
                if let existingIndex = existingHazardReportIndex {
                    self.hazardReports.remove(at: existingIndex)
                }
            }
        }
        self.hazardReports.sort { (firstReport, secondReport) -> Bool in
            firstReport.creationDate! < secondReport.creationDate!
        }
        
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
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "hazardReportCell",
                                                 for: indexPath)
        
        let displayHazardReport = self.hazardReports[indexPath.row]
        
        // Display date as main text
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy"
        
        if let creationDate = displayHazardReport.creationDate{ // since creationDate is optional
        cell.textLabel?.text = dateFormatter.string(from: creationDate)
        }
        
        // Display description as detailed text
        cell.detailTextLabel?.text = displayHazardReport.hazardDescription
        
        // Change icon if hazard is an emergency
        
        if displayHazardReport.isEmergency {
            cell.imageView?.image = UIImage(named: "emergency-hazard-icon")
        }
        else {
            cell.imageView?.image = UIImage(named: "hazard-icon")
        }
        
//
//        cell.textLabel?.text = "January 1, 2018"
//        cell.detailTextLabel?.text = "At the entrance to building 4 there's a puddle of water. I just about slipped and fell!"
        
        return cell
    }
    
    // MARK: TableView Delegate methods
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "hazardReportDetails":
            let destinationVC = segue.destination as! HazardReportDetailsViewController
            
            let selectedIndexPath = self.tableView.indexPathForSelectedRow!
            let selectedHazardReport = self.hazardReports[selectedIndexPath.row]
            
            destinationVC.hazardReport = selectedHazardReport
            
        case "addHazardReport":
            let navigationController = segue.destination as! UINavigationController
            _ = navigationController.viewControllers[0] as! EditHazardReportViewController
        default: break
        }
    }
}
