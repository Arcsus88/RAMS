import UIKit

struct RamsPDFBrandTheme {
    var companyName: String
    var tagline: String
    var legalFooterText: String
    var documentStatusText: String
    var primaryColor: UIColor
    var secondaryColor: UIColor
    var tertiaryColor: UIColor
    var tableGridColor: UIColor
    var sectionBackgroundColor: UIColor
    var logoImageData: Data?

    static let constructionDefault = RamsPDFBrandTheme(
        companyName: "ProRAMS Builder",
        tagline: "Risk Assessment & Method Statement",
        legalFooterText: "Controlled document. Uncontrolled when printed unless signed issue is attached.",
        documentStatusText: "LIVE / APPROVED",
        primaryColor: UIColor(red: 15 / 255, green: 23 / 255, blue: 42 / 255, alpha: 1), // slate-900
        secondaryColor: UIColor(red: 30 / 255, green: 41 / 255, blue: 59 / 255, alpha: 1), // slate-800
        tertiaryColor: UIColor(red: 250 / 255, green: 204 / 255, blue: 21 / 255, alpha: 1), // yellow-400
        tableGridColor: UIColor(red: 203 / 255, green: 213 / 255, blue: 225 / 255, alpha: 1), // slate-300
        sectionBackgroundColor: UIColor(red: 254 / 255, green: 249 / 255, blue: 195 / 255, alpha: 1), // yellow-100
        logoImageData: UIImage(named: "RAMSLogo")?.pngData()
    )
}
