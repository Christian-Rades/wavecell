{ stdenv, lib, fetchFromGitHub, zig }:

stdenv.mkDerivation rec {
  pname = "zls";
  version = "unstable-2021-06-06";

  src = fetchFromGitHub {
    owner = "zigtools";
    repo = pname;
    rev = "cb4e74213480113ea1af78aff70a90ba41777653";
    sha256 = "1hhs7dz9rpshfd1a7x5swmix2rmh53vsqskh3mzqlrj2lgb3cnii";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ zig ];

  preBuild = ''
    export HOME=$TMPDIR
  '';

  installPhase = ''
    zig build -Drelease-safe -Dcpu=baseline --prefix $out install
  '';

  meta = with lib; {
    description = "Zig LSP implementation + Zig Language Server";
    changelog = "https://github.com/zigtools/zls/releases/tag/${version}";
    homepage = "https://github.com/zigtools/zls";
    license = licenses.mit;
    maintainers = with maintainers; [ fortuneteller2k ];
  };
}
