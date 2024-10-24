{
  lib,
  tantivy-go-src,
  stdenvNoCC,
  rustPlatform,
  rust-cbindgen,
  cargo,
  cacert,
}:

let

  cargoHash = builtins.fromJSON (builtins.readFile ./cargoHash.json);

  srcPatchedHash = builtins.fromJSON (builtins.readFile ./src-patched.json);

  mkSrcPatched =
    hash:
    stdenvNoCC.mkDerivation {
      name = "tantivy-go-src-patched-${tantivy-go-src.version}";
      inherit (tantivy-go-src) src version;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        cd rust
        cargo generate-lockfile
        mkdir $out
        cp -r . $out
      '';
      outputHash = hash;
      outputHashMode = "recursive";
      nativeBuildInputs = [
        cacert
        cargo
      ];
    };

  srcPatched = mkSrcPatched srcPatchedHash;

  pkg =
    cargoHash:
    rustPlatform.buildRustPackage {

      name = "tantivy-go-${srcPatched.version}";

      inherit cargoHash;

      inherit (tantivy-go-src) version;

      src = srcPatched;

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
  passthru = {
    srcPatchedUpdate = mkSrcPatched lib.fakeHash;
    cargoHashUpdate = pkg lib.fakeHash;
  };
})
