{
  lib,
  tantivy-go-src,
  rustPlatform,
  rust-cbindgen,
}:

let

  cargoHash = lib.fakeHash;

  pkg =
    cargoHash:
    rustPlatform.buildRustPackage {

      name = "tantivy-go-${tantivy-go-src.version}";

      inherit cargoHash;

      inherit (tantivy-go-src) version;

      src = tantivy-go-src.src;

      nativeBuildInputs = [
        rust-cbindgen
      ];

      sourceRoot = "${tantivy-go-src.src.name}/rust";

      cargoLock = {
        lockFile = ./Cargo.lock;
      };
      postPatch = ''
        ln -s ${./Cargo.lock} Cargo.lock
      '';

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
    cargoHashUpdate = pkg lib.fakeHash;
  };
})
