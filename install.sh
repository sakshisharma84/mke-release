#!/bin/sh
set -e

PATH=$PATH:/usr/local/bin

if [ -n "${DEBUG}" ]; then
  set -x
fi

detect_uname() {
  os="$(uname)"
  case "$os" in
    Linux) echo "linux" ;;
    Darwin) echo "darwin" ;;
    *) echo "Unsupported operating system: $os" 1>&2; return 1 ;;
  esac
  unset os
}

detect_arch() {
  arch="$(uname -m)"
  case "$arch" in
    amd64) echo "amd64" ;;
    x86_64) echo "x64" ;;
    arm64|aarch64) echo "arm64" ;;
    armv7l|armv8l|arm) echo "arm" ;;
    *) echo "Unsupported processor architecture: $arch" 1>&2; return 1 ;;
  esac
  unset arch
}

# download_k0sctl_url() fetches the k0sctl download url.
download_k0sctl_url() {
  if [ "$arch" = "x64" ];
    then
      arch=amd64
  fi
  echo "https://github.com/k0sproject/k0sctl/releases/download/v$K0SCTL_VERSION/k0sctl-$uname-$arch"
}

# download_kubectl_url() fetches the kubectl download url.
download_kubectl_url() {
  if [ "$arch" = "x64" ];
  then
    arch=amd64
  fi
  echo "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${uname}/${arch}/kubectl"
}

install_kubectl() {
  if [ -z "${KUBECTL_VERSION}" ]; then
    echo "Using default kubectl version v1.30.0"
    KUBECTL_VERSION=v1.30.0
  fi
  kubectlDownloadUrl="$(download_kubectl_url)"
  echo "Downloading kubectl from URL: $kubectlDownloadUrl"
  curl -sSLf "$kubectlDownloadUrl" >$installPath/$kubectlBinary
  sudo chmod 755 "$installPath/$kubectlBinary"
  echo "kubectl is now executable in $installPath"
}

# download_mkectl downloads the mkectl binary.
download_mkectl() {
  if [ "$arch" = "x64" ] || [ "$arch" = "amd64" ];
  then
    arch=x86_64
  fi

 REPO_URL="https://github.com/MirantisContainers/mke-release"
 DOWNLOAD_URL="${REPO_URL}/releases/download/${MKECTL_VERSION}/mkectl_${uname}_${arch}.tar.gz"

 # Check if the version exists by checking HTTP status code with redirects enabled
 echo "Checking if the specified version exists..."
 HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L "$DOWNLOAD_URL")

 # If HTTP status code is not 200 (OK), the file does not exist or there was an error
 if [ "$HTTP_STATUS" -ne 200 ]; then
   echo "Error: The specified version ${MKECTL_VERSION} does not exist or is invalid." >&2
   exit 1
 fi

 # If the version exists, download the file
 echo "Downloading mkectl..."
 curl -s -L -o /tmp/mkectl.tar.gz "$DOWNLOAD_URL"

 # Verify the file is a valid gzip archive
 if [ -s /tmp/mkectl.tar.gz ] && file /tmp/mkectl.tar.gz | grep -q 'gzip compressed data'; then
   # Extract the downloaded file
   tar -xvzf /tmp/mkectl.tar.gz -C "$installPath"
   echo "mkectl is now executable in $installPath"
 else
   echo "Error: Downloaded file is empty or not a valid gzip archive." >&2
   exit 1
 fi
}

main() {

  uname="$(detect_uname)"
  arch="$(detect_arch)"

  printf "\n\n"

  echo "Step 1/3 : Install k0sctl"
  echo "#########################"

  if [ -z "${K0SCTL_VERSION}" ]; then
    echo "Using default k0sctl version 0.19.4"
    K0SCTL_VERSION=0.19.4
  fi

  k0sctlBinary=k0sctl
  installPath=/usr/local/bin
  k0sctlDownloadUrl="$(download_k0sctl_url)"


  echo "Downloading k0sctl from URL: $k0sctlDownloadUrl"
  curl -sSLf "$k0sctlDownloadUrl" >"$installPath/$k0sctlBinary"

  sudo chmod 755 "$installPath/$k0sctlBinary"
  echo "k0sctl is now executable in $installPath"

  printf "\n\n"
  echo "Step 2/3 : Install kubectl"
  echo "#########################"

  kubectlBinary=kubectl

  if [ -x "$(command -v "$kubectlBinary")" ]; then
    VERSION="$($kubectlBinary version | grep Client | cut -d: -f2)"
    echo "$kubectlBinary version $VERSION already exists."
  else
    install_kubectl
  fi

  printf "\n\n"
  echo "Step 3/3 : Install mkectl"
  echo "#########################"

  if [ -z "${MKECTL_VERSION}" ]; then
      # Determine the version
      # Get information about the latest release and pull version from the tag
      MKECTL_VERSION=$(curl -s https://api.github.com/repos/mirantiscontainers/mke-release/releases/latest | grep '"tag_name"' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '"' -f 2)

      if [ -z "${MKECTL_VERSION}" ]; then
        echo "Failed to retrieve the latest release version."
        exit 1
      fi

      echo "MKECTL_VERSION not set, using latest release: ${MKECTL_VERSION}"

  else
      # Make sure it is a valid version
      if ! curl -s https://api.github.com/repos/mirantiscontainers/mke-release/releases | grep -q "\"tag_name\": \"${MKECTL_VERSION}\""; then
          echo "Error: Invalid version specified: ${MKECTL_VERSION}"
          exit 1
      fi

      echo "Using specified version: ${MKECTL_VERSION}"
  fi

  printf "\n"


  echo "Downloading mkectl"
  download_mkectl

}

main "$@"
