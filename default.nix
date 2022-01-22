{
  pkgs ? (import <unstable>){}
}:

with pkgs;
let
  zls = import ./zls.nix {inherit (pkgs) stdenv lib fetchFromGitHub zig;};
in
stdenv.mkDerivation {
  name = "wavecell";
  src = [ ./src ./build.zig ];
  nativeBuildInputs = [ zig zls ];

  preBuild = ''
    export HOME=$TMPDIR
  '';

  unpackPhase = ''
    for srcFile in $src; do
      # Copy file into build dir
      local tgt=$(stripHash $srcFile)
      cp -r $srcFile $tgt
    done
  '';

  installPhase = ''
  ls -lah
    zig build -Drelease-safe -Dcpu=baseline --prefix $out install
  '';
}
