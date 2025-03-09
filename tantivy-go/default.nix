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
        outputHashes = {
          "ownedbytes-0.7.0" = "sha256-e2ffM2gRC5eww3xv9izLqukGUgduCt2u7jsqTDX5l8k=";
          "rust-stemmers-1.2.0" = "sha256-GJYFQf025U42rJEoI9eIi3xDdK6enptAr3jphuKJdiw=";
          "tantivy-jieba-0.11.0" = "sha256-BDz6+EVksgLkOj/8XXxPMVshI0X1+oLt6alDLMpnLZc=";
        };
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
