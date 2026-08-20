# Siri shortcuts

`play-p3.shortcut` and `stop-p3.shortcut` are **signed** Apple Shortcuts:
AEA1 (Apple Encrypted Archive) containers carrying an Apple-issued
`SigningCertificateChain` (produced by `shortcuts sign -m anyone`). They
cannot be edited or regenerated off-device — any byte change breaks the
signature and iOS refuses to import them.

## The embedded files must use POST

`/play` and `/stop` are POST-only; a GET returns 405. If a shortcut stops
working, it was exported with GET and must be re-exported with POST.

To re-export on an Apple device:

1.  Open the Shortcuts app, edit the shortcut's "Get Contents of URL"
    action: expand _Show More_ and set **Method: POST** (target URLs stay
    `http://<host>/play` and `http://<host>/stop`; no body needed —
    an empty POST to `/play` plays today's schedule).
2.  Export signed, on macOS:

        shortcuts sign -m anyone -i play-p3-unsigned.shortcut -o play-p3.shortcut

    (or share the shortcut via iCloud link and download the signed file).

3.  Replace the files here and rebuild; they are embedded via `go:embed`
    and served at `/shortcut/{name}`.
