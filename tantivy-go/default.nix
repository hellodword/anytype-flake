{ lib
, tantivy-go-src
, stdenv
, rustPlatform
, rust-cbindgen
}:

let

  cargoHash = builtins.fromJSON (builtins.readFile ./cargoHash.json);

  pkg = cargoHash: rustPlatform.buildRustPackage rec {

    name = "tantivy-go-${tantivy-go-src.version}";

    inherit cargoHash;

    inherit (tantivy-go-src) src version;

    sourceRoot = "${tantivy-go-src.src.name}/rust";

    nativeBuildInputs = [
      rust-cbindgen
    ];

    preBuild = ''
      mkdir -p $out/include
      sed -i "s@\"../bindings.h\"@\"$out/include/bindings.h\"@" src/build.rs
    '';

    buildPhase = ''
      runHook preBuild

      cargo build --release

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib
      cp -r target/release/libtantivy_go.a "$out/lib"

      runHook postInstall
    '';


    meta = with lib; {
      description = "Tantivy go bindings ";
      homepage = "https://github.com/anyproto/tantivy-go";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

in

(pkg cargoHash).overrideAttrs (old: {
  passthru.cargoHashUpdate = (pkg lib.fakeHash).goModules;
})
