# Rocky Linux 9 Desktop Cloud Image

Builds an x86_64 Rocky Linux 9 GenericCloud image with an Xfce desktop and
XRDP remote access. The resulting disk remains a QCOW2 image suitable for
cloud platforms or local QEMU testing.

## Image contents

- Xfce desktop with LightDM
- XRDP with the Xorg backend and clipboard support
- Firefox and Visual Studio Code
- Common administration tools including `vim`, `nmap`, and `net-tools`
- XRDP network-buffer tuning and an Xfce configuration optimized for remote use
- Full glibc locale coverage

## Releases

Ready-built images are published on the
[GitHub Releases](https://github.com/define42/rocky9-desktop-cloud-image/releases)
page. Release filenames use this format:

```text
rocky9-desktop-cloudimg-amd64-<branch>-<tag>.img
```

The `.img` release file uses the QCOW2 format.

## Local build

The local build requires a Linux x86_64 host with:

- GNU Make and `curl`
- `virt-customize` from libguestfs tools
- `qemu-img`
- `dhclient`
- `sudo` access when building as a non-root user

Build and compress the image:

```bash
make
```

The output is `rocky9-desktop-xrdp.qcow2`.

| Command | Purpose |
| --- | --- |
| `make download` | Download the latest Rocky Linux 9 GenericCloud base image |
| `make build` | Customize the base image without the final compression pass |
| `make compress` | Compress the customized image in place |
| `make clean` | Remove the customized output image |
| `make distclean` | Remove the output and downloaded base image |

The build downloads packages from Rocky Linux, EPEL, and Microsoft's Visual
Studio Code repository, so it requires internet access.

## Local QEMU test

Install `qemu-system-x86_64`, build the image, and run:

```bash
make run
```

The VM runs headless and forwards host port `2222` to SSH port `22`, and host
port `3390` to RDP port `3389`. KVM acceleration is enabled automatically when
`/dev/kvm` is available. The defaults are 4096 MiB of memory and two vCPUs.

Resource and port settings can be overridden on the command line:

```bash
make run RUN_MEMORY=8192 RUN_CPUS=4 RUN_SSH_PORT=2223 RUN_RDP_PORT=3391
```

The build does not set a password or inject an SSH key. Provision credentials
through cloud-init or your cloud platform before logging in; XRDP requires a
user with a password. Without provisioned credentials, `make run` is primarily
a boot test.

## GitHub Actions build

The [build workflow](.github/workflows/go.yml) runs for pushes and pull requests
against `main` and `xfce`. It downloads the Rocky Linux base image, then pulls
`ghcr.io/define42/virt-tools-container:latest` with `--pull=always`.

The prebuilt container supplies libguestfs and QEMU tooling. With the repository
mounted at `/workspace`, it runs `virt-customize`, `virt-sparsify`, and the final
`qemu-img convert`. `/dev/kvm` is passed through when the runner provides it.
The container definition is maintained in
[define42/virt-tools-container](https://github.com/define42/virt-tools-container).

Push builds that produce a new tag publish the converted image as a GitHub
release. Pull requests build the image for validation but do not publish it.

## Customization and security

Image changes are defined in [run-command.virt](run-command.virt), with the
supporting configuration files stored at the repository root.

The generated image disables IPv6 and configures SELinux in permissive mode.
The repository also installs a firewalld zone definition containing SSH and RDP
services; ensure the zone is assigned appropriately when provisioning the VM.

Both the Rocky Linux base image and the virt-tools container use mutable
`latest` references, so builds are not byte-for-byte reproducible. Review these
defaults before using the image in a production environment.
