
{ stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "mythweb";
  version = "31.0";

  src = fetchFromGitHub {
    owner = "mythtv";
    repo = "mythweb";
    rev = "v${version}";
    sha256 = "1kgxzm70rn071w6w7jjbasyvpf6jxsldl6c1gszdp1fzhv15qj0p";
  };

#  nativeBuildInputs = [ ruby.devEnv, zip ];

#  patches = [
#    ## Fix ruby path
#    ./fix-ruby-path.patch
#  ];

  installPhase = ''
    mkdir -p "$out/var/lib/mythtv/mythweb"/{image_cache,php_sessions}
    install -vDm755 "mythweb-$version"/* "$out/var/lib/mythtv/mythweb"
    chown -R http:http "$out/var/lib/mythtv/mythweb"
    chmod g+rw "$out/var/lib/mythtv/mythweb"/{image_cache,php_sessions}
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/MythTV/mythweb";
    description = "Web interface for the MythTV scheduler";
    license = licenses.gpl2Plus;
    platforms = platforms.all;
    maintainers = with maintainers; [ louisdk1 ];
  };

};
