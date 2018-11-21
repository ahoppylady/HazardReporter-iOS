import UIKit
import AVFoundation
import CoreLocation
import CloudKit

class EditHazardReportViewController: UIViewController,
    UINavigationControllerDelegate,
    UIImagePickerControllerDelegate,
CLLocationManagerDelegate {
    
    @IBOutlet weak var emergencySegmentedControl: UISegmentedControl!
    @IBOutlet weak var hazardDescriptionTextView: UITextView!
    @IBOutlet weak var hazardImageView: UIImageView!
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation? = nil
    
    var hazardReportToEdit: HazardReport?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        // Add border to hazard description text view
        hazardDescriptionTextView.layer.borderWidth = CGFloat(0.5)
        hazardDescriptionTextView.layer.borderColor = UIColor(red: 204/255,
                                                              green: 204/255,
                                                              blue: 204/255,
                                                              alpha: 1.0).cgColor
        hazardDescriptionTextView.layer.cornerRadius = 5
        hazardDescriptionTextView.clipsToBounds = true
        
        setInitalValue(hazardReportToEdit)
        
        startLocationServices()
    }
    
    func setInitalValue(_ hazardReport: HazardReport?) {
        guard let report = hazardReport else { return } //adding HazardReport not editing one
        //Editing an existing one
        self.emergencySegmentedControl.selectedSegmentIndex = report.isEmergency == false ? 0 : 1
        self.hazardDescriptionTextView.text = report.hazardDescription
        self.hazardImageView.image = report.hazardPhoto
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Track and Store Current Location
    func startLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        let locationAuthorizationStatus = CLLocationManager.authorizationStatus()
        
        switch locationAuthorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                self.locationManager.startUpdatingLocation()
            }
        case .restricted, .denied: alertLocationAccessNeeded()
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: break
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                self.locationManager.startUpdatingLocation()
            }
        case .restricted, .denied: alertLocationAccessNeeded()
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        self.currentLocation = locations.last
    }
    
    func alertLocationAccessNeeded() {
        let settingsAppURL = URL(string: UIApplication.openSettingsURLString)!
        
        let alert = UIAlertController(
            title: "Need Location Access",
            message: "Location access is required for including the location of the hazard.",
            preferredStyle: UIAlertController.Style.alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Allow Location Access",
                                      style: .cancel,
                                      handler: { (alert) -> Void in
                                        UIApplication.shared.open(settingsAppURL,
                                                                  options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]),
                                                                  completionHandler: nil)
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Present Camera and Snap Photo
    @IBAction func snapPictureButtonTapped(_ sender: UIButton) {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthorizationStatus {
        case .notDetermined: requestCameraPermission()
        case .authorized: presentCamera()
        case .restricted, .denied: alertCameraAccessNeeded()
        }
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video,
                                      completionHandler: {accessGranted in
                                        guard accessGranted == true else { return }
                                        self.presentCamera()
        })
    }
    
    func presentCamera() {
        let hazardPhotoPicker = UIImagePickerController()
        hazardPhotoPicker.sourceType = .camera
        hazardPhotoPicker.delegate = self
        
        self.present(hazardPhotoPicker, animated: true, completion: nil)
    }
    
    func alertCameraAccessNeeded() {
        let settingsAppURL = URL(string: UIApplication.openSettingsURLString)!
        
        let alert = UIAlertController(
            title: "Need Camera Access",
            message: "Camera access is required for including pictures of hazards.",
            preferredStyle: UIAlertController.Style.alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Allow Camera", style: .cancel, handler: { (alert) -> Void in
            UIApplication.shared.open(settingsAppURL,
                                      options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]),
                                      completionHandler: nil)
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        let hazardPhoto = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as! UIImage
        self.hazardImageView.image = hazardPhoto
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Cancelling & Saving
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
        
    }
    
    @IBAction func saveButtonTapped(_ sender: UIBarButtonItem) {
        
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        
        if var editedHazardReport = self.hazardReportToEdit {
            //Hazard report being edited
            editedHazardReport.hazardDescription = self.hazardDescriptionTextView.text
            editedHazardReport.hazardLocation = self.currentLocation
            editedHazardReport.hazardPhoto = self.hazardImageView.image
            editedHazardReport.isEmergency = self.emergencySegmentedControl.selectedSegmentIndex == 0 ? false : true
            
            // Send modifications to the cloud
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: [editedHazardReport.cloudKitRecord], recordIDsToDelete: nil)
            
            modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                guard let updatedRecord = savedRecords?.first else { return }
                
                NotificationCenter.default.post(name: recordDidChangeLocally,
                                                object: self,
                                                userInfo: ["recordChange" : RecordChange.updated(updatedRecord)])
            }
            database.add(modifyOperation)
            
        } else {
            //New Hazard report being created
        let hazardReport = HazardReport(hazardDescription: hazardDescriptionTextView.text,
                                        hazardLocation: currentLocation,
                                        hazardPhoto: hazardImageView.image,
                                        isEmergency: emergencySegmentedControl.selectedSegmentIndex == 0 ? false : true,
                                        isResolved: false)
        
            database.save(hazardReport.cloudKitRecord) { (savedRecord, error) in
                guard let createdRecord = savedRecord else { return }
                
                NotificationCenter.default.post(name: recordDidChangeLocally,
                                                object: self,
                                                userInfo: ["recordChange" : RecordChange.created(createdRecord)] )
        
            }
        }
        self.dismiss(animated: true, completion: nil)
        
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
