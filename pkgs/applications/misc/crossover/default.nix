{ multiStdenv, pkgs, lib, fetchurl, python3, python2, python2Packages, python3Packages, desktop-file-utils, gcc_multi, glibc_multi, gtk3, libICE, libSM, libX11, libXext, libXi, freetype, libpng, zlib, lcms2, libGL, libXcursor, libXrandr, libGLU
}:

# This package installs as a trial version valid for 14 days.
# You'll be able to sign in to unlock the software if you have a license.
# It's possible to obtain a license from the companys website.
let 
#  myPython = python3.withPackages(ps: [ ps.dbus-python ps.pygobject3 ]);
#  myPython2 = python2.withPackages(ps: [ ps.pygtk ]);
  myPython = python3.withPackages(ps: [ ps.pygobject3 ]);
  myPython2 = python2.withPackages(ps: [ ps.dbus-python ]);
in
multiStdenv.mkDerivation rec {
  pname = "crossover";
  version = "19.0.2";

  src = fetchurl {
    url = "https://media.codeweavers.com/pub/${pname}/cxlinux/demo/${pname}_${version}-1.deb";
    sha256 = "134s0zzi74vlvb9bj84zc1f197lrllavmgl7dhriga7djk4m77s6";
  };

  unpackPhase = ''
    ar x $src
    tar xf data.tar.xz
  '';

  nativeBuildInputs = [ python3 desktop-file-utils ];
  buildInputs = [ gcc_multi glibc_multi myPython myPython2
    python2Packages.dbus-python python3Packages.pygobject3 gtk3 libICE libSM libX11 libXext libXi freetype libpng zlib lcms2 libGL libXcursor libXrandr libGLU ];
  propagatedBuildInputs = [ python3 gcc_multi glibc_multi python2Packages.dbus-python python3Packages.pygobject3 gtk3 ];

  patchPhase = ''
    substituteInPlace opt/cxoffice/bin/crossover \
      --replace "python3" "${lib.getBin myPython}/bin/python3"
  '';

  installPhase = ''
    mkdir -p $out/share
#    install -vDm 755 usr/share/* $out/share/
    cp -a opt/cxoffice/{bin,lib,share,doc} $out/
    cp -a usr/share/*/ $out/share/    
  '';

  meta = with lib; {
    homepage = "https://www.codeweavers.com/products/crossover-linux";
    license = licenses.unfree;
    description = "Easy-to-use container-based GUI for Wine";
    platforms = [ "x86_64-linux" "i686-linux" ];
    maintainers = with maintainers; [ louisdk1 ];
  };
}

