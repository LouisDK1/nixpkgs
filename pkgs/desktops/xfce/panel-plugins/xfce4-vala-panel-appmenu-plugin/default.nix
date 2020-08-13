{ stdenv, fetchFromGitHub, substituteAll, callPackage, pkgconfig, cmake, vala, libxml2,
  glib, pcre, gtk2, gtk3, xorg, libxkbcommon, epoxy, at-spi2-core, dbus-glib, bamf,
  xfce, libwnck3, libdbusmenu, gobject-introspection, harfbuzz }:

stdenv.mkDerivation rec {
  pname = "xfce4-vala-panel-appmenu-plugin";
  version = "0.7.3.2";

  src = fetchFromGitHub {
    owner = "rilian-la-te";
    repo = "vala-panel-appmenu";
    rev = version;
    fetchSubmodules = true;

    sha256 = "0xxn3zs60a9nfix8wrdp056wviq281cm1031hznzf1l38lp3wr5p";
  };

  nativeBuildInputs = [ pkgconfig cmake vala libxml2.bin ];
  buildInputs = [ (callPackage ./appmenu-gtk-module.nix {})
                  glib pcre gtk2 gtk3 xorg.libpthreadstubs xorg.libXdmcp libxkbcommon epoxy
                  at-spi2-core dbus-glib bamf xfce.xfce4panel_gtk3 xfce.libxfce4util xfce.xfconf
                  libwnck3 libdbusmenu gobject-introspection harfbuzz ];

  patches = [
    (substituteAll {
      src = ./fix-bamf-dependency.patch;
      bamf = bamf;
    })
  ];

  NIX_CFLAGS_COMPILE = [ "-I${harfbuzz.dev}/include/harfbuzz" ];

  cmakeFlags = [
      "-DENABLE_XFCE=ON"
      "-DENABLE_BUDGIE=OFF"
      "-DENABLE_VALAPANEL=OFF"
      "-DENABLE_MATE=OFF"
      "-DENABLE_JAYATANA=OFF"
      "-DENABLE_APPMENU_GTK_MODULE=OFF"
  ];

  preConfigure = ''
    mv cmake/FallbackVersion.cmake.in cmake/FallbackVersion.cmake
  '';

  passthru.updateScript = xfce.updateScript {
    inherit pname version;
    attrPath = "xfce.${pname}";
    versionLister = xfce.gitLister src.meta.homepage;
  };

  meta = with stdenv.lib; {
    description = "Global Menu applet for XFCE4";
    license = licenses.lgpl3Only;
    maintainers = with maintainers; [ jD91mZM2 ];
  };
}
