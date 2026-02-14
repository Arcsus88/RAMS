import UIKit

struct RamsPDFBrandTheme {
    var companyName: String
    var tagline: String
    var legalFooterText: String
    var primaryColor: UIColor
    var secondaryColor: UIColor
    var tertiaryColor: UIColor
    var tableGridColor: UIColor
    var sectionBackgroundColor: UIColor
    var logoImageData: Data?

    static let constructionDefault = RamsPDFBrandTheme(
        companyName: "Arcsus Construction",
        tagline: "Risk Assessment & Method Statement Management",
        legalFooterText: "Controlled document. Uncontrolled when printed unless signed issue is attached.",
        primaryColor: UIColor(red: 20 / 255, green: 68 / 255, blue: 116 / 255, alpha: 1),
        secondaryColor: UIColor(red: 13 / 255, green: 45 / 255, blue: 78 / 255, alpha: 1),
        tertiaryColor: UIColor(red: 232 / 255, green: 240 / 255, blue: 249 / 255, alpha: 1),
        tableGridColor: UIColor(white: 0.78, alpha: 1),
        sectionBackgroundColor: UIColor(red: 232 / 255, green: 240 / 255, blue: 249 / 255, alpha: 1),
        logoImageData: UIImage(named: "RAMSLogo")?.pngData()
    )
}
