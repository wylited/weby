#import "setup.typ": format, center, right, title
#show: format

#set document(
    title: [Oneclick Decryption\ PolyUCTF 2026]
)

#set heading(numbering: "1.")

#line(length: 100%)

#title()

#line(length: 100%)

= Preface

Challenge "Bitbreaker" (category: Forensics / Crypto).

#set quote(block: true)

#quote[
One click decryption of cracking bitlocker
]

This challenge involves a multi-stage forensic investigation of a VMware virtual machine, requiring us to break through VMware encryption, recover BitLocker keys from vTPM/NVRAM, and ultimately crack an encrypted Excel spreadsheet to retrieve the flag.

= Reconnaissance

We start with a split tar archive (`Bitbreaker.tar.001`, `Bitbreaker.tar.002`). Concatenating and extracting them reveals a VMware virtual machine directory `Windows 11 CTF/`.

// Screenshot: show the extracted folder contents including .vmx, .vmdk, and .nvram files.
// Emphasize the .nvram and .vmx files.

The key files are:
- `Windows 11 CTF.vmx`: The VM configuration file.
- `Windows 11 CTF.vmdk`: The virtual disk.
- `Windows 11 CTF.nvram`: The NVRAM state file (encrypted).

Inspecting `Windows 11 CTF.vmx` reveals partial encryption. The configuration shows `encryption.required.vtpm = "TRUE"`, indicating the presence of a virtual TPM, which is essential for BitLocker.

= VMware Encryption & NVRAM Decryption

The `.vmx` file uses partial encryption to protect the vTPM keys. We need to recover the encryption password.

The password hash can be extracted from the `keySafe` field in the `.vmx` file. Using `hashcat` with mode *27400* (VMware VMX) and a wordlist like `rockyou.txt`, we recover the password:

*P\@ssw0rd*

With the password, we derive the encryption keys:
1. *Derive the PBKDF2 key* from the password and salt.
2. *Decrypt the `keySafe` data* to get the XTS key.
3. *Decrypt the `encryption.data` field* to retrieve the *`dataFileKey`*.
4. *Use the `dataFileKey`* to decrypt `Windows 11 CTF.nvram` via AES-CBC.

The decrypted NVRAM gives us access to the virtual TPM's internal state.

= BitLocker Recovery

The virtual disk `Windows 11 CTF.vmdk` is encrypted with BitLocker. The encryption keys are "sealed" inside the virtual TPM (vTPM).

To recover the keys, we must replicate the TPM's unsealing process manually using the decrypted NVRAM:

1. *Extract the Sealed Blob*: We parse the BitLocker metadata to find the TPM-protected key protector (containing `TPM2B_PRIVATE` and `TPM2B_PUBLIC` structures).

2. *Locate the SRK Seed*: We search the decrypted NVRAM to find the *Storage Root Key (SRK) seed* (located in the vTPM NVM region, around offset `0x24F3`).

3. *Derive the Unsealing Keys*: Using the seed, we calculate the storage hierarchy keys using the TPM's *KDFa* function:
   - `AES_Key = KDFa(seed, "STORAGE", name, 128)`
   - `HMAC_Key = KDFa(seed, "INTEGRITY", 256)`

4. *Decrypt and Extract VMK*: We verify the blob's integrity with the HMAC key, then decrypt the sensitive area using the AES key. This reveals the *Volume Master Key (VMK)*:

`9a9b99cace8500794ee30a9ba459e82638b67bf782e87ca68c3db3a7bda4346a`

5. *Unlock the Volume*: Finally, we use the VMK to decrypt the *Full Volume Encryption Key (FVEK)* and mount the NTFS partition.

= Forensics & Finding the Password File

Exploring the decrypted NTFS volume, we find a user profile `nuttyshell`. Inside `Users\nuttyshell\Documents\`, there is an interesting file:

*`password.xlsx`*

// Screenshot: show the file listing of the decrypted volume, highlighting password.xlsx in the Documents folder.

This file is an encrypted Office 2013 workbook. We need to crack it to proceed.

= Cracking password.xlsx

We can use `msoffcrypto-tool` or `office2john` to crack the password.
First, we generate a hash:

```bash
python3 office2john.py password.xlsx > hash.txt
```

Then we run a wordlist attack. Given the "One click" hint and the nature of CTF challenges, we try common passwords first.

// Screenshot: show John the Ripper or a python script cracking the password successfully.

The password is found to be:

*123456*

With the password, we can decrypt the workbook:

```python
import msoffcrypto

with open('password.xlsx', 'rb') as f:
    office = msoffcrypto.OfficeFile(f)
    office.load_key(password='123456')
    with open('password.decrypted.xlsx', 'wb') as out:
        office.decrypt(out)
```

= Retrieving the Flag

Opening the decrypted `password.decrypted.xlsx` reveals a table of credentials:

// Screenshot: show the content of the decrypted Excel file (table with 3 rows).

- *Name*: Bitlocker Recovery Key
- *Password*: `246763-099165-117249-698049-390687-345895-288255-504372`
- *Description*: Bitlocker key important!!!

The *BitLocker Recovery Key* matches the volume we decrypted. While we used the TPM exploit to get in, this key would have also worked if we had it earlier.

The relevant entry is:
- *Name*: Secret Pastebin Document
- *Password*: `8aRjmcBQix`
- *Description*: super secret document on pastebin

We also found a Pastebin URL in the browser history (Edge): `https://pastebin.com/PezhJTLJ`.

Visiting the URL and entering the password `8aRjmcBQix` unlocks a paste titled "Syuuuuuuper Sekreeettttt Messsageee" containing a base64 string:

`UFVDVEYyNntCaXQxMGNrM3JfMTVfbjB0X3MwXzVlY3VyM184YzIzMGY4NGE2YTgzYWNlNmE1MWRlYmY2YmFiNWQzMn0=`

Decoding this gives the flag:

```bash
$ echo "UFVDVEYyNntCaXQxMGNrM3JfMTVfbjB0X3MwXzVlY3VyM184YzIzMGY4NGE2YTgzYWNlNmE1MWRlYmY2YmFiNWQzMn0=" | base64 -d
PUCTF26{Bit10ck3r_15_n0t_s0_5ecur3_8c230f84a6a83ace6a51debf6bab5d32}
```

#line(length: 100%)
