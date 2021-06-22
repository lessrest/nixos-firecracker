{ self }:
{ config, pkgs, lib, ... }:

let
  rig-start =
    pkgs.writeShellScriptBin "rig-start" (
      let
        initPath = "/nix/var/nix/profiles/system/init";
        image =
          self.firecracker-rootfs;
        imagePath = "${image}/nixos.img";
        kernel =
          "${self.firecracker-vmlinux}/vmlinux";
        kernelOpts =
          "console=ttyS0 reboot=k panic=1 pci=off init=${initPath}";
      in ''
        mkdir -p $1
        SOCKET=$1/socket
        ROOT=$1/root.ext4
        rm -f $SOCKET $ROOT

        ${pkgs.coreutils}/bin/cp ${imagePath} "$ROOT"
        ${pkgs.coreutils}/bin/chmod 700 "$ROOT"

        mac=$(( 0xAAFC00000000 + $1 ))
        mac_hex=$(printf "%012x" $mac | sed 's/../&:/g;s/:$//')

        exec ${pkgs.firectl}/bin/firectl \
          --firecracker-binary=${pkgs.firecracker}/bin/firecracker \
          --root-drive="$ROOT" \
          --kernel="${kernel}" \
          --kernel-opts="${kernelOpts}" \
          --socket-path="$SOCKET" \
          --memory=4096 \
          --tap-device=tap$1/"$mac_hex"
      ''
    );

  # firecrackerService = i:
  #   {
  #     wantedBy = ["multi-user.target"];
  #     after = ["network.target"];
  #     description = "Firecracker Guest ${toString i}";
  #     serviceConfig = {
  #       Type = "simple";
  #       User = "mbrock";
  #       RuntimeDirectory = "firecracker/${toString i}";
  #       ExecStart = "${script} ${toString i}";
  #     };
  #   };

  instances =
    lib.forEach
      (lib.range 1 config.restless.firecracker.networkSize)
      (i: {
        number = i;
        tapName = "tap${toString i}";
        hostname = "vm${toString i}";
        localHostname = "vm${toString i}.local";
        ip = "172.16.${toString i}.2";
      });

in {
  # options.restless.firecracker.instances =
  #   lib.mkOption {
  #     type = lib.types.listOf lib.types.attrs;
  #     default = [];
  #     example = [{ hostName = "foo"; } { hostName = "bar"; }];
  #   };

  options.restless.firecracker.networkSize =
    lib.mkOption {
      type = lib.types.ints.between 0 254;
      default = 0;
    };

  options.restless.firecracker.hostnameFunction =
    lib.mkOption {
      type = lib.types.functionTo lib.types.string;
      default = { hostname, ... }: hostname;
    };

  config = {
    # systemd.services = builtins.listToAttrs (
    #   lib.imap1 (i: _: {
    #     name = "firecracker-${toString i}";
    #     value = firecrackerService i;
    #   }) instances
    # );

    environment.systemPackages = [rig-start];

    networking.interfaces = builtins.listToAttrs (
      builtins.map (instance:
        let i = toString instance.number;
        in {
          name = instance.tapName;
          value = {
            virtual = true;
            virtualOwner = "mbrock";
            ipv4.addresses = [{
              address = "172.16.${toString i}.1";
              prefixLength = 24;
            }];
          };
        }
      ) instances
    );

    networking.nat.internalInterfaces =
      builtins.map (x: "tap${toString x.number}") instances;

    networking.extraHosts = lib.concatMapStrings (x: ''
      ${x.ip} ${x.localHostname}
    '') instances;

    services.nginx = {
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
    };

    services.nginx.virtualHosts =
      builtins.listToAttrs (
        builtins.map (instance: {
          name = "${instance.hostname}.node.town";
          value = {
            serverAliases = [
              "${instance.hostname}.node.town"
              "${instance.hostname}.tty.node.town"
            ];
            forceSSL = true;
            useACMEHost = "node.town";
            locations = {
              "/" = {
                proxyPass = "http://${instance.ip}:80";
                proxyWebsockets = true;
              };
            };
          };
        }) instances
      );

    services.dhcpd4 = {
      enable =
        true;
      interfaces =
        lib.forEach instances ({ tapName, ... }: tapName);
      extraConfig = let
        instanceConfig = instance:
          let i = toString instance.number;
          in ''
            subnet 172.16.${i}.0 netmask 255.255.255.0 {
              range 172.16.${i}.2 172.16.${i}.254;
              option routers 172.16.${i}.1;
            }

            host guest-${i} {
              hardware ethernet aa:fc:00:00:00:0${i};
              option host-name "${
                config.restless.firecracker.hostnameFunction instance
              }";
            }
          '';

        in ''
          option domain-name-servers 1.1.1.1, 8.8.8.8;
          option subnet-mask 255.255.0.0;

          ${lib.concatMapStrings instanceConfig instances}
        '';
    };
  };
}
