# Decrypting the firmware (pointers only — no keys here)

This repository **does not** contain Yamaha firmware or the encryption keys. You work
with your **own** device's firmware. The encryption scheme was publicly reverse
engineered and documented by **lab313ru**; use that to decrypt your own files and to
produce a correctly-encrypted payload.

## The scheme (as publicly documented)
- The USB update is an **OpenSSL salted AES-128-CBC** stream: files begin with the
  `Salted__` magic and use the classic OpenSSL `EVP_BytesToKey` (MD5) key derivation.
- The firmware ships a key blob; lab313ru's script derives the working passphrase from
  it, then uses that passphrase with `openssl enc -d -aes-128-cbc -md md5 -kfile <pass>`
  to decrypt each component (`mcu.enc`, `update.enc`, `yamaha_usb_upgrade.enc`).

## Public sources (lab313ru)
Search for lab313ru's YAS-109 / Yamaha soundbar gists and notes. The two gists this
work used are reachable by their GitHub gist IDs:

- `https://gist.github.com/474fc32f76ce3c23698d905dc0df16af` — the key/file decrypt script
- `https://gist.github.com/c36f44b472e1389f8297b8afaf07ac3f` — the stock `yamaha_usb_upgrade.sh` (reference)

(If those IDs ever move, search GitHub for "lab313ru yas-109" / "yamaha soundbar firmware decrypt".)

## Producing the install payload
Once you can decrypt, you can **encrypt** `scripts/install-fix.sh` back into a
`yamaha_usb_upgrade.enc` using the **same OpenSSL parameters** the stock updater
expects (same cipher, same `-md md5`, same passphrase/key derivation). Verify your
round-trip first: encrypt a known plaintext, decrypt it, confirm it is byte-identical,
**before** you ever flash. Do not include `update.zip` or `uImage_ota_mcu` in the
payload — their absence is what makes the stock updater drop the files without
flashing firmware.

## Why it isn't automated here
Shipping a one-command encryptor would mean shipping (or trivially reconstructing)
Yamaha's key material and bundling their updater script. This project keeps that out on
purpose. You reproduce it from the public sources above against your own firmware.
