import UIKit
import FirebaseStorage
import PDFKit
import FirebaseAuth

class PDFViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!

    let storage = Storage.storage()
    let storageRef = Storage.storage().reference()
    var pdfURLs: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        fetchPDFURLs()
    }

    // Function to fetch PDF URLs from Firebase Storage
    func fetchPDFURLs() {
        let pdfsRef = storageRef.child("pdfs").child(Auth.auth().currentUser?.uid ?? "Test") // Adjust the path accordingly

        print(pdfsRef)
        
        pdfsRef.listAll { result, error in
            if let error = error {
                print("Error fetching PDFs: \(error)")
                return
            }

            for item in result!.items {
                item.downloadURL { url, error in
                    if let url = url {
                        self.pdfURLs.append(url)
                        self.tableView.reloadData()
                    } else if let error = error {
                        print("Error getting PDF download URL: \(error)")
                    }
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pdfURLs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PDFCell", for: indexPath) as! PDFTableViewCell

        let pdfURL = pdfURLs[indexPath.row]
        print("Loading PDF from URL:", pdfURL)

        let pdfView = PDFView(frame: cell.pdfContainerView.bounds)
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if let pdfDocument = PDFDocument(url: pdfURL) {
            pdfView.document = pdfDocument
            cell.pdfContainerView.addSubview(pdfView)
        } else {
            print("Error loading PDF document from URL:", pdfURL)
        }

        return cell
    }

    


    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Calculate cell height based on PDF content
        if let pdfDocument = PDFDocument(url: pdfURLs[indexPath.row]) {
            let pageSize = pdfDocument.page(at: 0)?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)
            let scaleFactor = tableView.frame.width / pageSize.width
            let scaledHeight = pageSize.height * scaleFactor
            return scaledHeight
        }
        return 200.0 // Default height if unable to calculate
    }
}

class PDFTableViewCell: UITableViewCell {
    @IBOutlet weak var pdfContainerView: UIView!
    // ...
}

