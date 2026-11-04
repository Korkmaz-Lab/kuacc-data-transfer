# Direct WeTransfer → KUACC download

Download large **multi-file WeTransfer ZIP archives** directly to KUACC, without storing the files on your laptop. Uses the upstream [`iamleot/transferwee`](https://github.com/iamleot/transferwee) Python helper to resolve the direct URL, then `curl` for resumable downloading.

> **Scope:** This script is intended for WeTransfer links that yield a ZIP archive, such as a collection of FASTQ files. It does **not** automatically extract, overwrite, or delete existing experiment files. Single-file links that return a raw FASTQ instead of ZIP are not supported by this script.

## Requirements

- KUACC account and an **approved transfer/login node** (follow KUACC's data transfer policy)
- An approved destination directory with enough free space, preferably lab project storage instead of `$HOME`
- Python 3 with the `requests` package, `curl`, `unzip`, `sha256sum`
- Internet access from that KUACC node and a valid WeTransfer link

If off-campus, connect to the university VPN if required for SSH access.

## One-time setup

Log in to KUACC:

```bash
ssh YOUR_USERNAME@login.kuacc.ku.edu.tr
```

Once this repository is published, clone it on KUACC:

```bash
git clone https://github.com/Korkmaz-Lab/kuacc-data-transfer.git
cd kuacc-data-transfer
```

## Download a dataset

On KUACC, run:

```bash
bash wetransfer_to_kuacc.sh 'https://we.tl/YOUR_LINK' '/PATH/TO/APPROVED/PROJECT'
```

The script will:

1. Create the destination directory if missing.
2. Obtain the direct download URL via `transferwee.py` (cached in `~/.cache/kuacc-data-transfer/`).
3. Download into a `.zip.part` file using `curl -C - --retry 10 --retry-delay 5`.
4. Test the ZIP archive with `unzip -tq` before renaming it to `.zip`.
5. Skip an already-downloaded ZIP **only if it passes ZIP validation**.

Different WeTransfer links are given different file names (for example, `wetransfer_012345abcdef.zip`). The original FASTQ files in the destination directory are not modified.

## If the connection drops

Run **the exact same command** again. A partially downloaded `.zip.part` file is kept for resumption. Resuming requires the remote server to support HTTP Range requests and the WeTransfer link to remain valid; neither is guaranteed. Do **not** delete the partial file unless you intend to restart.

Use a KUACC-approved persistent session such as `tmux` for long downloads if available, and comply with the cluster's login/transfer node policies.

## Verification and extraction

The script checks ZIP structure and CRC with `unzip -tq`, but a successful ZIP test is **not equivalent** to checking the sequencing provider's MD5 values.

Inspect contents first:

```bash
unzip -l /PATH/TO/APPROVED/PROJECT/wetransfer_<ID>.zip
```

Extract only after inspecting paths and available disk space. For example:

```bash
unzip -n /PATH/TO/APPROVED/PROJECT/wetransfer_<ID>.zip -d /PATH/TO/APPROVED/PROJECT/extracted
```

`-n` avoids replacing existing files. It does **not** verify that skipped files are complete. If the provider supplied an MD5 manifest, check it after extraction:

```bash
cd /PATH/TO/APPROVED/PROJECT/extracted
md5sum -c checksums.md5
```

Adapt the checksum command to the actual manifest format, if one was supplied.

## Security and maintenance

- **Never commit** patient datasets, actual WeTransfer links, credentials, SSH keys, or signed download URLs to GitHub.
- Check the lab's data governance rules before transferring patient-derived or restricted sequencing data.
- `transferwee.py` is **third-party code** and is cached from its upstream `master` branch on first use; review it and consider pinning to an approved commit before deploying widely.
- The upstream WeTransfer interface may change; this workflow is known to have worked in one KUACC environment, but is not a guaranteed long-term API.
- Do not delete source data until archive integrity and any supplied MD5 checksums are verified.
