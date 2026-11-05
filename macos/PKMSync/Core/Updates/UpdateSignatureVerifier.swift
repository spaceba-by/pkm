import Foundation
import Security

/// Checks that a downloaded app was signed by us before it replaces the running copy.
///
/// HTTPS only proves the bytes came from GitHub, not that they came from our release pipeline.
enum UpdateSignatureVerifier {
    /// A Developer ID Application certificate from our team, on our bundle identifier.
    static let developerIDRequirement = """
    anchor apple generic and identifier "by.spaceba.pkm.sync" \
    and certificate 1[field.1.2.840.113635.100.6.2.6] exists \
    and certificate leaf[field.1.2.840.113635.100.6.1.13] exists \
    and certificate leaf[subject.OU] = "TPXD65QGEQ"
    """

    static func verify(appAt appURL: URL, requirement: String = developerIDRequirement) throws {
        var staticCode: SecStaticCode?
        try check(SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode))
        guard let staticCode else {
            throw UpdateError.signatureInvalid("Could not read the code signature")
        }

        var secRequirement: SecRequirement?
        try check(SecRequirementCreateWithString(requirement as CFString, [], &secRequirement))

        let flags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode
        )
        var validityError: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(staticCode, flags, secRequirement, &validityError)
        guard status == errSecSuccess else {
            let detail = validityError?.takeRetainedValue().localizedDescription ?? message(for: status)
            throw UpdateError.signatureInvalid(detail)
        }
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw UpdateError.signatureInvalid(message(for: status))
        }
    }

    private static func message(for status: OSStatus) -> String {
        SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
    }
}
