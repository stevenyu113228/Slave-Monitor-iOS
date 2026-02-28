import Foundation
import SwiftTerm
import UIKit

class TerminalBridge: NSObject, TerminalViewDelegate {
    let client: TtydClient
    weak var terminalView: TerminalView?

    init(client: TtydClient) {
        self.client = client
        super.init()

        client.onOutput = { [weak self] data in
            guard let terminal = self?.terminalView else { return }
            let bytes = Array(data)
            terminal.feed(byteArray: ArraySlice(bytes))
        }
    }

    // MARK: - TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        client.sendInput(Array(data))
    }

    func scrolled(source: TerminalView, position: Double) {
        // No-op: scrollback handled natively by SwiftTerm
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        // Title updates come via WebSocket TITLE frames
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        client.sendResize(cols: newCols, rows: newRows)
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        if let text = String(data: content, encoding: .utf8) {
            UIPasteboard.general.string = text
        }
    }

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        // No-op
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // No-op
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
        if let url = URL(string: link) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }
}
