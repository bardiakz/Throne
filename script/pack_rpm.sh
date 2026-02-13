#!/bin/bash
set -e

version="$1"

# Save current directory (should be deployment/)
DEPLOY_DIR=$(pwd)

if [[ $(uname -m) == 'aarch64' || $(uname -m) == 'arm64' ]]; then
  ARCH="arm64"
  ARCH_RPM="aarch64"
else
  ARCH="amd64"
  ARCH_RPM="x86_64"
fi

# Install rpm-build if not present
if ! command -v rpmbuild &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y rpm
fi

# Create RPM build directory structure
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create the application directory structure
INSTALL_DIR=~/rpmbuild/BUILD/throne-${version}
mkdir -p ${INSTALL_DIR}/opt/Throne
mkdir -p ${INSTALL_DIR}/usr/share/applications
mkdir -p ${INSTALL_DIR}/usr/share/icons/hicolor/512x512/apps

# Copy application files (using absolute path)
cp -r ${DEPLOY_DIR}/linux-${ARCH}/* ${INSTALL_DIR}/opt/Throne/
rm -f ${INSTALL_DIR}/opt/Throne/Throne.debug
chmod +x ${INSTALL_DIR}/opt/Throne/Throne
chmod +x ${INSTALL_DIR}/opt/Throne/Core

# Create desktop entry
cat > ${INSTALL_DIR}/usr/share/applications/throne.desktop <<EOF
[Desktop Entry]
Name=Throne
Comment=Qt based cross-platform GUI proxy configuration manager (backend: sing-box)
Exec=sh -c "PATH=/opt/Throne:\$PATH /opt/Throne/Throne -appdata"
Icon=throne
Terminal=false
Type=Application
Categories=Network;Application;
EOF

# Copy icon
cp ${DEPLOY_DIR}/linux-${ARCH}/Throne.png ${INSTALL_DIR}/usr/share/icons/hicolor/512x512/apps/throne.png

# Create spec file
cat > ~/rpmbuild/SPECS/throne.spec <<EOF
Name:           throne
Version:        ${version}
Release:        1%{?dist}
Summary:        Qt based cross-platform GUI proxy configuration manager

License:        GPL
URL:            https://github.com/throneproj/throne
Source0:        %{name}-%{version}.tar.gz

Requires:       desktop-file-utils

%description
Throne is a Qt based cross-platform GUI proxy configuration manager
with sing-box backend. This package bundles its Qt runtime.

%prep
%setup -q

%build
# No build needed, pre-compiled binaries

%install
rm -rf \$RPM_BUILD_ROOT
mkdir -p \$RPM_BUILD_ROOT
cp -r * \$RPM_BUILD_ROOT/

%post
update-desktop-database &> /dev/null || :

%postun
update-desktop-database &> /dev/null || :

%files
/opt/Throne/*
/usr/share/applications/throne.desktop
/usr/share/icons/hicolor/512x512/apps/throne.png

%changelog
* $(date "+%a %b %d %Y") Throne Team <team@throne.dev> - ${version}-1
- Release version ${version}
EOF

# Create tarball
cd ~/rpmbuild/BUILD
tar czf ~/rpmbuild/SOURCES/throne-${version}.tar.gz throne-${version}

# Build RPM
cd ~/rpmbuild
rpmbuild -ba SPECS/throne.spec

# Return to deployment directory
cd ${DEPLOY_DIR}

# Copy the built RPM
cp ~/rpmbuild/RPMS/${ARCH_RPM}/throne-${version}-1.*.rpm ./Throne.rpm 2>/dev/null || {
    echo "Error: Could not find RPM package"
    ls -la ~/rpmbuild/RPMS/*/
    exit 1
}

echo "RPM package created successfully: Throne.rpm"
