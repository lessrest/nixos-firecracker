{ nixpkgs } :
{ pkgs, config, lib, ... }:

let
  kernel = pkgs.linux_5_12;

in {
  boot.isContainer = true;
  boot.loader.grub.enable = false;
  fileSystems."/" = { device = "/dev/vda"; };
  
  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nix.registry.nixpkgs.flake = nixpkgs;

  boot.kernelPackages = pkgs.linuxPackages_custom {
    inherit (kernel) src version;
    configfile = ./firecracker-kernel.config;
  };

  environment.variables.NIX_REMOTE = lib.mkForce "";

  networking = {
    hostName = "firecracker";
    useHostResolvConf = false;
    usePredictableInterfaceNames = false;
    enableIPv6 = false;
    dhcpcd.enable = false;
    interfaces.eth0.ipv4.addresses = [{
      address = "172.16.0.2";
      prefixLength = 24;
    }];
    defaultGateway = "172.16.0.1";
    nameservers = ["1.1.1.1" "8.8.8.8"];
  };

  services.mingetty.autologinUser = "root";
  users.users.root.initialHashedPassword = "";

  system.activationScripts.installInitScript = ''
    mkdir -p /sbin
    ln -fs $systemConfig/init /sbin/init
  '';

  boot.postBootCommands =
    ''
      # After booting, register the contents of the Nix store in the Nix
      # database.
      if [ -f /nix-path-registration ]; then
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration &&
        rm /nix-path-registration
      fi
      # nixos-rebuild also requires a "system" profile
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    '';

  environment.systemPackages = with pkgs; [
    clojure
    ruby
  ];
}
