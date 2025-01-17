{ self }:
{ pkgs, ... }:
{
  name = "anytype-execute-test";
  nodes.machine = {
    imports = [
      "${pkgs.path}/nixos/tests/common/x11.nix"
    ];
    config = {
      environment.systemPackages = [
        self.packages.${pkgs.system}.anytype
      ];
    };
  };

  testScript = ''
    machine.wait_for_x()
    machine.succeed("sleep 20")
    machine.wait_until_succeeds("xwininfo -root -tree")
    machine.execute(
      "anytype --no-sandbox >&2 &"
    )
    machine.succeed("sleep 10")
    machine.wait_for_window("Anytype")
  '';

}
