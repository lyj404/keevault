import AuthenticationServices
import UIKit

/// KeeStone Credential Provider Extension entry point.
///
/// On `prepareCredentialList(forServiceIdentifiers:)` it loads the encrypted
/// snapshot from the App Group container (written by the main app while the
/// vault is unlocked), matches the requested web domain, and shows a list.
/// Tapping a row returns an `ASPasswordCredential`. If the snapshot is missing
/// (vault locked / autofill disabled) it offers a button to open KeeStone.
class CredentialProviderViewController: ASCredentialProviderViewController {
    private var candidates: [Matcher.Candidate] = []
    private var serviceIdentifier: ASCredentialServiceIdentifier?
    private var snapshotMissing = false

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func prepareCredentialList(forServiceIdentifiers serviceIdentifiers: [ASCredentialServiceIdentifier]?) {
        serviceIdentifier = serviceIdentifiers?.first
        let domain = serviceIdentifier?.identifier

        if let snapshot = SnapshotStore.load() {
            candidates = Matcher.match(snapshot, domain: domain)
            snapshotMissing = false
        } else {
            candidates = []
            snapshotMissing = true
        }
        setupUI()
        tableView.reloadData()
    }

    /// KeeStone requires user interaction to fill (no silent fill from a
    /// possibly-stale snapshot).
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        extensionContext.cancelRequest(withError: ASExtensionError.userInteractionRequired)
    }

    private func setupUI() {
        title = "KeeStone"
        view.backgroundColor = .systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func openKeeStone() {
        // Ask the host to open the app; the extension cannot pause.
        let url = URL(string: "keestone://unlock")
        if let url = url {
            _ = extensionContext.open(url, completionHandler: nil)
        }
        extensionContext.cancelRequest(withError: ASExtensionError.userCanceled)
    }

    private func complete(with candidate: Matcher.Candidate) {
        let identity = ASPasswordCredentialIdentity(
            serviceIdentifier: serviceIdentifier
                ?? ASCredentialServiceIdentifier(identifier: "", type: .domain),
            user: candidate.entry.username,
            recordIdentifier: candidate.entry.uuid
        )
        let cred = ASPasswordCredential(
            identity: identity,
            password: candidate.entry.password
        )
        extensionContext.completeRequest(withSelectedCredential: cred, completionHandler: nil)
    }
}

extension CredentialProviderViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if snapshotMissing { return 1 }
        return max(candidates.count, 1) // 1 row for "no matches" state
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if snapshotMissing { return "Vault is locked or autofill is disabled." }
        if candidates.isEmpty { return "No matching credentials found." }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if snapshotMissing {
            cell.textLabel?.text = "Open KeeStone to unlock"
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell
        }
        if candidates.isEmpty {
            cell.textLabel?.text = "Open KeeStone to choose"
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell
        }
        let c = candidates[indexPath.row]
        let title = c.entry.title.isEmpty ? c.entry.username : c.entry.title
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = c.entry.username
        cell.accessoryType = .none
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if snapshotMissing || candidates.isEmpty {
            openKeeStone()
            return
        }
        complete(with: candidates[indexPath.row])
    }
}
